----------------------------------------------------------------------------------
-- Thuong Nguyen    
-- Pulse Generator
-- Credit from Lab 3 Hint
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity pulseGenerator is
    Port ( 
           -- input
           clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           maxCount : in unsigned (26 downto 0);
           -- output
           pulseOut : out STD_LOGIC);
end pulseGenerator;

architecture Behavioral of pulseGenerator is
    signal pulseCnt: unsigned (26 downto 0);
    signal clear: std_logic;

begin
    --Pulse Generator
    process(clk, reset)
    begin
        if(reset = '1') then
            pulseCnt <= (others => '0');
        elsif(rising_edge(clk)) then
            if(clear='1') then              -- when clear to high, the pulseCnt reset to 0 in the next rising edge of the clk
                pulseCnt <= (others => '0');
            else
                pulseCnt <= pulseCnt + 1;
            end if;
        end if;
    end process;
    
    clear <= '1' when (pulseCnt = maxCount) else '0';
    pulseOut <= clear;
end Behavioral;
