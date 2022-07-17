----------------------------------------------------------------------------------
-- Thuong Nguyen 
-- VGA Controller
-- This file is the VGA controller for VGA display
-- the veritcal counter and horizontal counter is used as output to use in the top component
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga is
 Port ( 
           -- inputs
           clk100MHz : in STD_LOGIC;             
           reset: in STD_LOGIC;  
           
           --outputs                        
           Hsync: out STD_LOGIC;
           VSync: out STD_LOGIC;
           vgaRed: out STD_LOGIC_VECTOR(3 downto 0);
           vgaGreen: out STD_LOGIC_VECTOR(3 downto 0);
           vgaBlue: out STD_LOGIC_VECTOR(3 downto 0);
           hcnt: out UNSIGNED(7 downto 0) ; -- 8bits counter horizontal position of the red square(match the horizontal_counter (9 downto 5)) 
           vcnt: out UNSIGNED(7 downto 0) -- 8 bits counter vertical position of the red square match the vertical_counter (9 downto 5)) 
                                           
           );                
end vga;

architecture Behavioral of vga is
     -- row constants
    constant H_TOTAL: unsigned(9 downto 0) := to_unsigned(799, 9+1);
    constant Hsync_Max: unsigned(9 downto 0) := to_unsigned(752, 9+1);
    constant Hsync_Min: unsigned(9 downto 0) := to_unsigned(656, 9+1);
    constant Hdisplay_Min: unsigned(9 downto 0) := to_unsigned(0, 9+1);
    constant Hdisplay_Max: unsigned(9 downto 0) := to_unsigned(640,9+1);

    -- column constants
    constant V_TOTAL:  unsigned(9 downto 0) := to_unsigned(520,9+1);
    constant Vsync_Max: unsigned(9 downto 0) := to_unsigned(492, 9+1);
    constant Vsync_Min: unsigned(9 downto 0) := to_unsigned(490, 9+1);
    constant Vdisplay_Min: unsigned(9 downto 0) := to_unsigned(0,9+1);
    constant Vdisplay_Max: unsigned(9 downto 0) := to_unsigned(480,9+1);
    
    signal en25 : std_logic;                                       -- enable for 25MHz clock
    signal MaxCounter1 : unsigned(26 downto 0);                    -- maxium counter to match to the MaxCount from pulseGenerator
    signal horizontal_counter: unsigned (9 downto 0);
    signal vertical_counter: unsigned (9 downto 0);
    
    signal h_cnt: unsigned(7 downto 0) ; -- 8bits counter horizontal position of the red square(match the horizontal_counter (9 downto 5)) 
    signal v_cnt: unsigned(7 downto 0); -- 8 bits counter vertical position of the red square match the vertical_counter (9 downto 5)) 
        
    signal vgaRedT: std_logic;
    signal vgaGreenT: std_logic;
    signal vgaBlueT: std_logic;
    
    
begin

-- pulse generator components
-- generate 25MHz clock enable pulse using a 100 MHz clock. 
 pulseGenerator: entity work.pulseGenerator port map 
    (
        clk => clk100MHz,
        reset => reset,
        MaxCount => MaxCounter1,
        pulseOut => en25
    );
    
    MaxCounter1 <= "000000000000000000000000100"; -- binary value for 4 to generate 25MHz pulse
    
    -- Calculate vertical counter and horizoltal counter base on the 25MHz clock
    vga_clk_25: process(clk100MHz, reset)
    begin
        if(reset = '1') then
            horizontal_counter <= (others => '0');
            vertical_counter <= (others => '0');
        elsif(rising_edge(clk100MHz)) then
            if(en25 = '1') then       
                if(horizontal_counter = H_TOTAL) then           -- when the horizontal counter reach 799, reset to zero
                    horizontal_counter <= (others => '0');      
                     if(vertical_counter = V_TOTAL) then        -- when the vertical counter reach 520, reset to zero
                        vertical_counter <= (others => '0');
                    else
                        vertical_counter <= vertical_counter + 1;  -- when the horizontal counter is reset, the vertical counter start to count
                    end if;
                else
                    horizontal_counter <= horizontal_counter + 1;  
                end if;                     
            end if;
        end if;
    end process vga_clk_25;
    
   --Write a CSA to assign '0' to a signal named Hsync when horizontal_counter is between [656,752) otherwise assign '1'. 
    Hsync <= '0' when ((horizontal_counter >= Hsync_Min) and (horizontal_counter < Hsync_Max)) else
             '1';

   --Write a CSA to assign '0' to a signal named Vsync when vertical_counter is between [490,492) otherwise assign '1'
   Vsync <= '0' when ((vertical_counter >= VSync_Min) and (vertical_counter < Vsync_Max)) else
             '1';
             
    
    -- Make checkerboard, each square is 32x32 
        -- Alternating the green and blue square
        -- Check for the bit(5) of vertical_counter and horizontal_counter. 
        -- The green square lication is where the bit5 horizontal counter and vertical counter both = 1 or the bit5 horizontal counter and vertical counter both equal 0
        -- otherwise is the blue square
        -- Green and blue squares are static making a 15 rows x 20 columns checkerboard
        -- The red square location is the bits beyond the 5th bit for the vertical and horizontal counter (hcount(9 downto 5) or vcount(9 downto 5))
        checkerboard: process (horizontal_counter,vertical_counter, v_cnt, h_cnt)
        begin
            if(horizontal_counter(9 downto 5) = h_cnt and vertical_counter(9 downto 5) = v_cnt )then
                vgaGreenT <= '0';  
                vgaBlueT <= '0';
                vgaRedT <= '1';
            elsif((horizontal_counter(5) = '1' and vertical_counter(5) = '1')
                or (horizontal_counter(5) = '0' and vertical_counter(5) = '0') ) then
                vgaGreenT <= '1';  
                vgaBlueT <= '0';
                vgaRedT <= '0';
            else
                vgaGreenT <= '0';  
                vgaBlueT <= '1';
                vgaRedT <= '0';
            end if;          
        end process checkerboard;
    
    --Write a CSA to assign '1' to signals vgaRedT, vgaGreenT, vgaBlueT otherwise 0 .  
    vgaRed <= "1111" when vgaRedT = '1' else "0000";
    vgaGreen <= "1111" when vgaGreenT = '1' else "0000";
    vgaBlue <= "1111" when vgaBlueT = '1' else "0000";
    
    -- Assign vertical_counter to vcounter to use at the other component
    -- Assign horizontal_counter to hcounter to use at the other component
    
    hcnt <= h_cnt;
    vcnt <= v_cnt;

end Behavioral;