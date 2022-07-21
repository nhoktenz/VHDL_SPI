----------------------------------------------------------------------------------
-- Thuong Nguyen
-- Seg7_controller
-- This file is to write 8 seperate characters for simultaneous displays
-- The seven-segment controller requires a clock, reset, and eight characters (4 bits each) as inputs. 
-- The outputs of the controller are the eight cathodes (seven segments plus decimal point) and the eight anode signals
--
-- This file is to design a driver that displays different digits on the 7-segment displays
-- First step is to create an entity called seg7_controller which requires the master 100MHz clock, an active high reset, and eight characters as 4-bit inputs each.
-- The outputs of the controller are the encoded character as the cathodes and the anode signal. 
-- Each character should be represented as an std_logic_vector(3 downto 0).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_signed.all;
use work.all;


entity seg7_controller is
    Port ( 
           -- inputs
           clk : in STD_LOGIC;                                      -- system clock
           reset : in STD_LOGIC;                                    -- reset
           -- 8 displays inputs 
           character0 : in STD_LOGIC_VECTOR (31 downto 28);
           character1 : in STD_LOGIC_VECTOR (27 downto 24);
           character2 : in STD_LOGIC_VECTOR (23 downto 20);
           character3 : in STD_LOGIC_VECTOR (19 downto 16);
           character4 : in STD_LOGIC_VECTOR (15 downto 12);
           character5 : in STD_LOGIC_VECTOR (11 downto 8);
           character6 : in STD_LOGIC_VECTOR (7 downto 4);
           character7 : in STD_LOGIC_VECTOR (3 downto 0);
           --outputs
           encode_character : out STD_LOGIC_VECTOR (7 downto 0);    -- cathodes output for 7seg_hex
           AN : out STD_LOGIC_VECTOR (7 downto 0));                 -- anodes output
end seg7_controller;

architecture Behavioral of seg7_controller is
     signal cntr3bit: unsigned (2 downto 0);                        -- counter from 0 to 8 every pulse to generate anodes and cathodes
     signal char: std_logic_vector (3 downto 0);                    -- cathodes output
     constant MaxCounter1 : unsigned(26 downto 0) := to_unsigned(100000,27);  -- 100 000 to generate 1kHz pulse (100M / 100k = 1k)
     signal Pulse1KHz : std_logic;                                  -- pulse out every 1kHz
begin
    -- import pulse Generator from the other file 
    -- then map the port
    pulseGenerator: entity work.pulseGenerator port map 
    (
        clk => clk,
        reset => reset,
        MaxCount => MaxCounter1,
        pulseOut => Pulse1KHz
    );
    
    --Generate 1kHZ pulse.
        kHZclock: process(clk, reset)
            begin
                if(reset = '1') then
                    cntr3bit <= (others => '0');
                elsif(rising_edge(clk)) then
                    if(Pulse1KHz = '1') then        -- use pulse as increment to the 3bit counter. Each pulse is generated as 1kHZ
                        cntr3bit <= cntr3bit + 1;  
                    end if;
                end if;
            end process kHZclock;
    
    -- set anodes and cathodes from 1kHZ pulse clock. 
    -- Anodes: Having a '0' for any given anode does cause that display to turn on with whatever is currently on the cathodes   
    
    anodes_control: process(reset,cntr3bit)
    begin
        if (reset = '1') then
            AN <= "00000000";
        else
            if (cntr3bit = "000") then
                AN <= "11111110";
            elsif (cntr3bit = "001")then
                AN <= "11111101";
            elsif (cntr3bit = "010") then
                AN <= "11111011";
            elsif (cntr3bit ="011") then
                AN <= "11110111";
            elsif (cntr3bit = "100") then
                AN <= "11101111";
            elsif (cntr3bit = "101") then
                AN <= "11011111";
            elsif (cntr3bit = "110")then
                AN <= "10111111";
            else
                AN <= "01111111";
             end if;
        end if;     
    end process anodes_control;
    
    -- Cathodes: Make 7segment_hex - cathodes - cathodes will be sync to anodes so that whichever anode is on, the cathodes of that anode will be on  
    cathodes_control: process (reset,cntr3bit,character0,character1,character2,character3,character4,character5,character6,character7)
    begin
        if (reset = '1') then
            char <= "0000";
        else
            if (cntr3bit = "000") then
                char <= character0;
            elsif (cntr3bit = "001")then
                char <= character1;
            elsif (cntr3bit = "010") then
                char <= character2;
            elsif (cntr3bit ="011") then
                char <= character3;
            elsif (cntr3bit = "100") then
                char <= character4;
            elsif (cntr3bit = "101") then
                char <= character5;
            elsif (cntr3bit = "110")then
                char <= character6;
            else
                char <= character7;
             end if;
        end if;     
    end process cathodes_control;
    
    --7seg_hex to make character from 0 to F 
    -- the cathodes output from the
    seg7_process: process(char) 
    begin
        case char is
            when x"0" =>
                encode_character <= "11000000";
            when x"1" => 
                encode_character <= "11111001";
            when x"2" =>
                encode_character <= "10100100";
            when x"3" =>
                encode_character <= "10110000";
            when x"4" =>
                encode_character <= "10011001";
            when x"5" =>
                encode_character <= "10010010";
            when x"6" =>
                encode_character <= "10000010";
            when x"7" =>
                encode_character <= "11111000";
            when x"8" =>
                encode_character <= "10000000";
            when x"9" =>
                encode_character <= "10010000";
            when x"A" =>
                encode_character <= "10001000";
            when x"B" =>
                encode_character <= "10000011";
            when x"C" =>
                encode_character <= "11000110";
            when x"D" =>
                encode_character <= "10100001";
            when x"E" =>
                encode_character <= "10000110";  
            when others =>
                encode_character <= "10001110";
        end case;
    end process seg7_process;
                

end Behavioral;
