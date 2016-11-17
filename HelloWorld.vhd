-------------------------------------------------
--Engineer: CaoSY
--Create Date: 2016/11/18
--Description:
--This program runs on Xilinx Basys3
--This program sends "Hello, world!" through UART
--when either of five buttons is pressed.
-------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
USE IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

entity HelloWorld is
    Port ( BTN 			: in  STD_LOGIC_VECTOR (4 downto 0);
           CLK 			: in  STD_LOGIC;
           UART_TXD 	: out  STD_LOGIC
          );
end HelloWorld;

architecture Behavioral of HelloWorld is

	component UART_TX_CTRL
	Port(
		SEND : in std_logic;
		DATA : in std_logic_vector(7 downto 0);
		CLK : in std_logic;          
		READY : out std_logic;
		UART_TX : out std_logic
		);
	end component;

	component debouncer
	Generic(
			DEBNC_CLOCKS : integer;
			PORT_WIDTH : integer);
	Port(
			SIGNAL_I : in std_logic_vector(4 downto 0);
			CLK_I : in std_logic;          
			SIGNAL_O : out std_logic_vector(4 downto 0)
			);
	end component;

	type CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);

	type UART_STATE_TYPE is (WAIT_BTN, LOAD_STR, SEND_CHAR, WAIT_RDY, RDY_LOW);
	signal uartState: UART_STATE_TYPE := WAIT_BTN;
	
	constant MAX_STR_LEN : integer := 14;

	--Contains the current string being sent over uart.
	signal sendStr : CHAR_ARRAY(0 to (MAX_STR_LEN - 1));
	signal dataStr : CHAR_ARRAY(0 to (MAX_STR_LEN - 1));
	
	--Contains the length of the current string being sent over uart.
	signal strEnd : natural;

	--Contains the index of the next character to be sent over uart
	--within the sendStr variable.
	signal strIndex : natural;

	--Used to determine when a button press has occured
	signal btnReg : std_logic_vector (4 downto 0) := "00000";
	signal btnDetect : std_logic;

	--UART_TX_CTRL control signals
	signal uartRdy : std_logic;
	signal uartSend : std_logic := '0';
	signal uartData : std_logic_vector (7 downto 0):= "00000000";
	signal uartTX : std_logic;

	--Debounced btn signals used to prevent single button presses
	--from being interpreted as multiple button presses.
	signal btnDeBnc : std_logic_vector(4 downto 0);

begin

	dataStr(4) <= (X"48",	--H
					X"65",	--e
					X"6C",	--l
					X"6C",	--l
					X"6F",	--o
					X"2C",	--,
					X"20",	--space
					X"77",	--w
					X"6F",	--o
					X"72",	--r
					X"6C",	--l
					X"64",	--d
					X"21",	--!
					X"0A",	--\n
				);
							 
	----------------------------------------------------------
	------              Button Control                 -------
	----------------------------------------------------------
	--Buttons are debounced and their rising edges are detected
	--to trigger UART messages
	
	--Debounces btn signals
	Inst_btn_debounce: debouncer 
		generic map(
			DEBNC_CLOCKS => (2**16),
			PORT_WIDTH => 5)
		port map(
			SIGNAL_I => BTN,
			CLK_I => CLK,
			SIGNAL_O => btnDeBnc
		);

	--Registers the debounced button signals, for edge detection.
	btn_reg_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			btnReg <= btnDeBnc;
		end if;
	end process;

	--btnDetect goes high for a single clock cycle when a btn press is
	--detected. This triggers a UART message to begin being sent.
	btnDetect <= '1' when ((btnReg(0)='0' and btnDeBnc(0)='1') or
							(btnReg(1)='0' and btnDeBnc(1)='1') or
							(btnReg(2)='0' and btnDeBnc(2)='1') or
							(btnReg(3)='0' and btnDeBnc(3)='1') or
							(btnReg(4)='0' and btnDeBnc(4)='1')) else
					  '0';
	
	
	----------------------------------------------------------
	------              UART Control                   -------
	----------------------------------------------------------
	--Messages are sent on reset and when a button is pressed.

	next_uartState_process: process(CLK)
	begin
		if (rising_edge(CLK)) then
			if (uartState=WAIT_BTN and btnDetect='1') then
				uartState <= LOAD_STR;
			else
				case uartState is
					when LOAD_STR =>
						uartState <= SEND_CHAR;
					when SEND_CHAR =>
						uartState <= RDY_LOW;
					when RDY_LOW =>
						uartState <= WAIT_RDY;
					when WAIT_RDY =>
						if (uartRdy='1') then
							if (strIndex=strEnd) then
								uartState <= WAIT_BTN;
							else
								uartState <= SEND_CHAR;
							end if;
						end if;
					when others =>
						uartState <= WAIT_BTN;
				end case;
			end if;
		end if;
	end process;
	
	load_data: process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (uartState=LOAD_STR) then
				sendStr <= dataStr;
				strEnd <= MAX_STR_LEN;
			end if;
		end if;
	end process;

	--Conrols the strIndex signal so that it contains the index
	--of the next character that needs to be sent over uart
	char_count_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (uartState = LOAD_STR) then
				strIndex <= 0;
			elsif (uartState = SEND_CHAR) then
				strIndex <= strIndex + 1;
			end if;
		end if;
	end process;
	
	--Controls the UART_TX_CTRL signals
	char_load_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (uartState = SEND_CHAR) then
				uartSend <= '1';
				uartData <= sendStr(strIndex);
			else
				uartSend <= '0';
			end if;
		end if;
	end process;
	
	--Component used to send a byte of data over a UART line.
	Inst_UART_TX_CTRL: UART_TX_CTRL port map(
			SEND => uartSend,
			DATA => uartData,
			CLK => CLK,
			READY => uartRdy,
			UART_TX => uartTX 
		);

	UART_TXD <= uartTX;


end Behavioral;



entity UART_TX_CTRL is
    Port ( SEND : in  STD_LOGIC;
           DATA : in  STD_LOGIC_VECTOR (7 downto 0);
           CLK : in  STD_LOGIC;
           READY : out  STD_LOGIC;
           UART_TX : out  STD_LOGIC);
end UART_TX_CTRL;

architecture Behavioral of UART_TX_CTRL is

type TX_STATE_TYPE is (RDY, LOAD_BIT, SEND_BIT);

	constant BIT_TMR_MAX : std_logic_vector(13 downto 0) := "10100010110000"; --10416 = (round(100MHz / 9600)) - 1
	constant BIT_INDEX_MAX : natural := 10;

	--Counter that keeps track of the number of clock cycles the current bit has been held stable over the
	--UART TX line. It is used to signal when the ne
	signal bitTmr : std_logic_vector(13 downto 0) := (others => '0');

	--combinatorial logic that goes high when bitTmr has counted to the proper value to ensure
	--a 9600 baud rate
	signal bitDone : std_logic;

	--Contains the index of the next bit in txData that needs to be transferred 
	signal bitIndex : natural;

	--a register that holds the current data being sent over the UART TX line
	signal txBit : std_logic := '1';

	--A register that contains the whole data packet to be sent, including start and stop bits. 
	signal txData : std_logic_vector(9 downto 0);

	signal txState : TX_STATE_TYPE := RDY;

begin

--Next state logic
next_txState_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			case txState is 
			when RDY =>
				if (SEND = '1') then
					txState <= LOAD_BIT;
				end if;
			when LOAD_BIT =>
				txState <= SEND_BIT;
			when SEND_BIT =>
				if (bitDone = '1') then
					if (bitIndex = BIT_INDEX_MAX) then
						txState <= RDY;
					else
						txState <= LOAD_BIT;
					end if;
				end if;
			when others=> --should never be reached
				txState <= RDY;
			end case;
		end if;
	end process;

	bit_timing_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (txState = RDY) then
				bitTmr <= (others => '0');
			else
				if (bitDone = '1') then
					bitTmr <= (others => '0');
				else
					bitTmr <= bitTmr + 1;
				end if;
			end if;
		end if;
	end process;

	bitDone <= '1' when (bitTmr = BIT_TMR_MAX) else
					'0';

	bit_counting_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (txState = RDY) then
				bitIndex <= 0;
			elsif (txState = LOAD_BIT) then
				bitIndex <= bitIndex + 1;
			end if;
		end if;
	end process;

	tx_data_latch_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (SEND = '1') then
				txData <= '1' & DATA & '0';
			end if;
		end if;
	end process;

	tx_bit_process : process (CLK)
	begin
		if (rising_edge(CLK)) then
			if (txState = RDY) then
				txBit <= '1';
			elsif (txState = LOAD_BIT) then
				txBit <= txData(bitIndex);
			end if;
		end if;
	end process;

	UART_TX <= txBit;
	READY <= '1' when (txState = RDY) else
				'0';

end Behavioral;



entity debouncer is
    Generic ( DEBNC_CLOCKS : INTEGER range 2 to (INTEGER'high) := 2**16;
              PORT_WIDTH : INTEGER range 1 to (INTEGER'high) := 5);
    Port ( SIGNAL_I : in  STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
           CLK_I : in  STD_LOGIC;
           SIGNAL_O : out  STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0));
end debouncer;

architecture Behavioral of debouncer is

	constant CNTR_WIDTH : integer := natural(ceil(LOG2(real(DEBNC_CLOCKS))));
	constant CNTR_MAX : std_logic_vector((CNTR_WIDTH - 1) downto 0) := std_logic_vector(to_unsigned((DEBNC_CLOCKS - 1), CNTR_WIDTH));
	type VECTOR_ARRAY_TYPE is array (integer range <>) of std_logic_vector((CNTR_WIDTH - 1) downto 0);

	signal sig_cntrs_ary : VECTOR_ARRAY_TYPE (0 to (PORT_WIDTH - 1)) := (others=>(others=>'0'));

	signal sig_out_reg : std_logic_vector((PORT_WIDTH - 1) downto 0) := (others => '0');

	begin

	debounce_process : process (CLK_I)
	begin
	if (rising_edge(CLK_I)) then
	for index in 0 to (PORT_WIDTH - 1) loop
		if (sig_cntrs_ary(index) = CNTR_MAX) then
			sig_out_reg(index) <= not(sig_out_reg(index));
		end if;
	end loop;
	end if;
	end process;

	counter_process : process (CLK_I)
	begin
		if (rising_edge(CLK_I)) then
		for index in 0 to (PORT_WIDTH - 1) loop
		
			if ((sig_out_reg(index) = '1') xor (SIGNAL_I(index) = '1')) then
				if (sig_cntrs_ary(index) = CNTR_MAX) then
					sig_cntrs_ary(index) <= (others => '0');
				else
					sig_cntrs_ary(index) <= sig_cntrs_ary(index) + 1;
				end if;
			else
				sig_cntrs_ary(index) <= (others => '0');
			end if;
			
		end loop;
		end if;
	end process;

	SIGNAL_O <= sig_out_reg;

end Behavioral;
