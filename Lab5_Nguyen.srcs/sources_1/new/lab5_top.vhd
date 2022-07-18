----------------------------------------------------------------------------------
-- Thuong Nguyen

----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.all;


entity lab5_top is
Port ( 
           -- Clock
           CLK100MHZ : in STD_LOGIC;
           -- Switch 0 as active high reset
           SW: in STD_LOGIC_VECTOR(3 downto 0); 
           
           --Push Buttons
           BTNU : in STD_LOGIC;
           BTND : in STD_LOGIC;
           BTNL : in STD_LOGIC;
           BTNR : in STD_LOGIC;
         
           -- VGA
           VGA_R: out STD_LOGIC_VECTOR(3 downto 0);
           VGA_G: out STD_LOGIC_VECTOR(3 downto 0);
           VGA_B: out STD_LOGIC_VECTOR(3 downto 0);
           VGA_HS: out STD_LOGIC;
           VGA_VS: out STD_LOGIC;
          
           --Seg7 Display Signals
           SEG7_CATH : out STD_LOGIC_VECTOR (7 downto 0);
           AN : out STD_LOGIC_VECTOR (7 downto 0);
           
           -- SPI 
           ACL_MISO: in STD_LOGIC;
           ACL_MOSI: out STD_LOGIC;
           ACL_SCLK: out STD_LOGIC;
           ACL_CSN: out STD_LOGIC
           );
end lab5_top;

architecture Behavioral of lab5_top is
    -- reset signal
    signal reset : std_logic;
    -- 7 segments display
    signal char0: std_logic_vector(31 downto 28);
    signal char1: std_logic_vector(27 downto 24);
    signal char2: std_logic_vector(23 downto 20);
    signal char3: std_logic_vector(19 downto 16);
    signal char4: std_logic_vector(15 downto 12);
    signal char5: std_logic_vector(11 downto 8);
    signal char6: std_logic_vector(7 downto 4);
    signal char7: std_logic_vector(3 downto 0);
    
    --VGA signals             
    signal vgaRedT: std_logic;
    signal vgaGreenT: std_logic;
    signal vgaBlueT: std_logic;
    signal hcnt: unsigned(7 downto 0) ; -- 8bits counter horizontal position of the red square(match the horizontal_counter (9 downto 5)) 
    signal vcnt: unsigned(7 downto 0); -- 8 bits counter vertical position of the red square match the vertical_counter (9 downto 5)) 
    constant HMax: unsigned(7 downto 0) := to_unsigned(20, 7+1); -- max column is 20
    constant VMax: unsigned(7 downto 0) := to_unsigned(15, 7+1); -- max row is 15
    
    -- BTNU
    signal btnUp_bd: std_logic; --button up debounce output
    signal btnUp_db_prev: std_logic; -- button up debounce is one clock cycle delayed
    signal btnUp_press_event: std_logic; 
    
    -- BTND
    signal btnDown_bd: std_logic; --button down debounce output
    signal btnDown_db_prev: std_logic; -- button up debounce is one clock cycle delayed
    signal btnDown_press_event: std_logic; 
    
    -- BTNL
    signal btnLeft_bd: std_logic; --button left debounce output
    signal btnLeft_db_prev: std_logic; -- button up debounce is one clock cycle delayed
    signal btnLeft_press_event: std_logic; 
    
    -- BTNR
    signal btnRight_bd: std_logic; --button right debounce output
    signal btnRight_db_prev: std_logic; -- button up debounce is one clock cycle delayed
    signal btnRight_press_event: std_logic; 


  signal DATA_X:  std_logic_vector(7 downto 0); 
  signal DATA_Y :  std_logic_vector(7 downto 0); 
  signal DATA_Z :  std_logic_vector(7 downto 0); 
  signal ID_AD :  std_logic_vector(7 downto 0); 
  signal ID_1D :  std_logic_vector(7 downto 0); 

begin
 -- switch 0 is reset
   reset <= SW(0);     
   
 -- switch 1 high => go to SPI Accel
    
     
     ------------------------------------------------------------------------------------           
     ------------------------------------- VGA ------------------------------------------   
     ------------------------------------------------------------------------------------ 
     
     -- vga port map -- 
     vga: entity work.vga port map 
        (
           clk100MHz => CLK100MHZ,             
           reset => reset,                         
           Hsync => VGA_HS,
           VSync => VGA_VS,
           vgaRed => VGA_R,
           vgaGreen => VGA_G,
           vgaBlue => VGA_B,
           hcnt => hcnt,
           vcnt => vcnt
         );
        
        
     ------------------------------------------------------------------------------------           
     ------------------------------------- SPI ACEL -------------------------------------   
     ------------------------------------------------------------------------------------ 
     
     accel_spi: entity work.accel_spi_rw port map
     (
        clk => CLK100MHZ, 
        reset => reset, 
      DATA_X => DATA_X, 
      DATA_Y => DATA_Y,
      DATA_Z => DATA_Z,
      ID_AD => ID_AD,
      ID_1D => ID_1D,
      CSb => ACL_CSN,
      MOSI => ACL_MOSI,
      SCLK => ACL_SCLK, 
      MISO => ACL_MISO 
     );
     
       
     -----------------------------------------------------------------------------------      
     -------------------------------------- BUTTONS ------------------------------------
     -----------------------------------------------------------------------------------
     
     --------BUTTON UP -------------
     -- button up debounce port map
     btnUpDebounce: entity btn_debounce port map
     (
        clk => CLK100MHZ,
        reset => reset,
        pb0 => BTNU,
        pb0db => btnUp_bd
     );
     -- process to assign the button up debounce output one clock cycle delayed
     btnU_enable: process(CLK100MHZ, reset)
     begin
        if (reset = '1') then
            btnUp_db_prev <= '0';
        elsif (rising_edge(CLK100MHZ)) then
            btnUp_db_prev <= btnUp_bd;      -- previous value of button pushed
        end if;    
     end process btnU_enable;
     
     btnUp_press_event <= '1' when btnUp_bd = '1' and btnUp_db_prev = '0' else '0';
        
    ----- BUTTON DOWN ----------
    -- button down debounce port map
     btnDownDebounce: entity btn_debounce port map
     (
        clk => CLK100MHZ,
        reset => reset,
        pb0 => BTND,
        pb0db => btnDown_bd
     );
      -- process to assign the button down debounce output one clock cycle delayed
     btnD_enable: process(CLK100MHZ, reset)
     begin
        if (reset = '1') then
            btnDown_db_prev <= '0';
        elsif (rising_edge(CLK100MHZ)) then
            btnDown_db_prev <= btnDown_bd; -- previous value of button pushed
        end if;    
     end process btnD_enable;
     
     btnDown_press_event <= '1' when btnDown_bd = '1' and btnDown_db_prev = '0' else '0'; 
     
     --------BUTTON LEFT -------------
     -- button left debounce port map
      btnLeftDebounce: entity btn_debounce port map
     (
        clk => CLK100MHZ,
        reset => reset,
        pb0 => BTNL,
        pb0db => btnLeft_bd
     );
      -- process to assign the button left debounce output one clock cycle delayed
     btnL_enable: process(CLK100MHZ, reset)
     begin
        if (reset = '1') then
            btnLeft_db_prev <= '0';
        elsif (rising_edge(CLK100MHZ)) then
            btnLeft_db_prev <= btnLeft_bd; -- previous value of button pushed
        end if;    
     end process btnL_enable;
     
     btnLeft_press_event <= '1' when btnLeft_bd = '1' and btnLeft_db_prev = '0' else '0';
        
    ----- BUTTON RIGHT ----------
    -- button right debounce port map
      btnRightDebounce: entity btn_debounce port map
     (
        clk => CLK100MHZ,
        reset => reset,
        pb0 => BTNR,
        pb0db => btnRight_bd
     );
      -- process to assign the button right debounce output one clock cycle delayed
     btnR_enable: process(CLK100MHZ, reset)
     begin
        if (reset = '1') then
            btnRight_db_prev <= '0';
        elsif (rising_edge(CLK100MHZ)) then
            btnRight_db_prev <= btnRight_bd; -- previous value of button pushed
        end if;    
     end process btnR_enable;
     
     btnRight_press_event <= '1' when btnRight_bd = '1' and btnRight_db_prev = '0' else '0';
       
    -- Design a process for a 8-bits counter with an enable that counts everytime the enable goes high
    -- When buttons is press, it set the location for the red square
    -- verical count and horizontal count is set to 0 when reset switch is switch on
    btn_counter: process(CLK100MHZ, reset)
    begin
        if(reset = '1') then                    -- verical count and horizontal count is set to 0 when reset switch is switch on
            hcnt <= (others => '0');
            vcnt <= (others => '0');
         elsif(rising_edge(CLK100MHZ)) then
             if(vcnt = VMax) then               -- set vertical counter to 0 when it reach the max value which is 15
                 vcnt <= (others => '0');
             else
                if(btnUp_press_event = '1') then 
                    if(vcnt = "00000000") then      -- set the vertical counter to max value - 1 (because 0 is the first number) when its value is 0 and button up is pressed
                        vcnt <= VMax -1;
                    else
                        vcnt <= vcnt - 1;
                    end if;
                    
                elsif (btnDown_press_event = '1') then
                    vcnt <= vcnt + 1;
                else
                    vcnt <= vcnt;
                end if;
             end if;
             if(hcnt = HMax) then       -- set horizontal counter to 0 when it reaches its max which is 20
                 hcnt <= (others => '0');
             else
                if (btnLeft_press_event = '1') then -- if button left is pressed and the horizontal counter reach to 0 then set horizontal counter to its max value -1 (because 0 is the first value)
                    if(hcnt = "00000000") then
                        hcnt <= HMax - 1;
                    else
                         hcnt <= hcnt - 1;
                    end if;
                   
                 elsif (btnRight_press_event = '1') then
                   hcnt <= hcnt + 1;
                else
                    hcnt <= hcnt;
                end if;
             end if;                            
        end if;
    end process btn_counter;

    ------------------------------------------------------------------------------------
    ------------------------------------- 7 SEGMENTS DISPLAY --------------------------
    ------------------------------------------------------------------------------------
    
    -- 7 segments controller port map     
   seg7Controller: entity seg7_controller port map 
    (
        clk => CLK100MHZ, 
        reset =>  reset,
        character0 => char0, 
        character1 => char1,  
        character2  => char2, 
        character3  => char3, 
        character4  => char4,
        character5  => char5, 
        character6  => char6,
        character7 => char7, 
        encode_character => SEG7_CATH, -- cathodes
        AN => AN                       -- anodes
    );
    
    -- display the 8bit counters using the seven-segment display   
    -- the first 2 segments display (char0 and char1) display the vertical position of the red square
    -- the next 2 segments display (char 2 and char3) display the horizontal position of the red square  
    char0 <= std_logic_vector(vcnt(3 downto 0));
    char1 <= std_logic_vector(vcnt(7 downto 4));
    char2 <= std_logic_vector(hcnt(3 downto 0));
    char3 <= std_logic_vector(hcnt(7 downto 4));
    
    -- SW(4:3) of '00' shows the values of register 0x01 in 7-segment displays 7 and 6 and values of register 0x00 in display 5 and 4
    -- SW(4:3) of '01' shows the value of register 0x08 in display 5 and 4 and should have all zeros on display 6 and 7
    -- SW(4:3) of '10' shows the value of register 0x09 in display 5 and 4 and should have all zeros on display 6 and 7
    -- SW(4:3) of '11' shows the value of register 0x0A in display 5 and 5 and should have all zeros on display 6 and 7
    char4 <= (others => '0');
    char5 <= (others => '0');
    char6 <= (others => '0');
    char7 <= (others => '0');

end Behavioral;
