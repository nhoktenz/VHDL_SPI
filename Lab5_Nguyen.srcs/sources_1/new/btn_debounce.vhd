----------------------------------------------------------------------------------
-- Thuong Nguyen
-- Button Debounce component that eliminates bouncing
-- Assume that the button is pressed for 0.1 seconds or longer
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity btn_debounce is
  Port ( 
        clk:   in  std_logic;
        reset: in std_logic;
        pb0:   in  std_logic;
        pb0db: out std_logic
    );
end btn_debounce;

architecture Behavioral of btn_debounce is
    constant delay : unsigned(23 downto 0) := to_unsigned(10000000, 23 +1);  --delay time is 10 000 000 
    signal counter : unsigned(23 downto 0); 
begin

-- Counter that increments as long as you press button. 
-- If counter > 10,000,000, then acknowledge press
btn_debounce:
process(clk, reset)
    begin
        if(reset = '1') then
            counter <= (others => '0');
        elsif (rising_edge(clk)) then
            if(pb0 = '1') then
                if (counter < delay) then
                    counter <= counter +1;
                else
                    pb0db <= '1';
                end if;
            else
                pb0db <= '0';
                counter <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
