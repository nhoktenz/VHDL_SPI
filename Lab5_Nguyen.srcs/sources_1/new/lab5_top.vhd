----------------------------------------------------------------------------------
-------------------------- Thuong Nguyen -----------------------------------------
----------------------------------------------------------------------------------
-- This project creates a green / blue 15 rows x 20 columns checkerboard 
-- This project is the combination of the Accelerator and the button pressed on the Nexys 4 DDR 
-- SW1 goes high will activate the accelerometer
-- When the accelerometer is activated:
------Tilt the board to the right, the red square moves to the right one
------Tilt the board to the left, the red square moves to the left one
------Tilt the boatd up, the red square moves up one
------Tile the board down, the red square moves down one
-- SW1 goes low, the button up/down/left/right will move the red square up/down/left/right one
-- SW(4:3): 
----- SW(4:3) of '00' shows the values of register 0x01 on 7-segment displays 6 and 7 and values of register 0x00 in display 4 and 5
----- SW(4:3) of '01' shows the value of register 0x08 on display 4 and 5 and should have all zeros on display 6 and 7
----- SW(4:3) of '10' shows the value of register 0x09 on display 4 and 5 and should have all zeros on display 6 and 7
----- SW(4:3) of '11' shows the value of register 0x0A on display 4 and 5 and should have all zeros on display 6 and 7

--- ** In addition: 
----- SW(2) goes high show the DataX (register 0x08) on display 4 and 5 and DataY (register 0x09) on display 6 and 7
---- LED 5 lit up when red square is at x = 0
---- LED 6 lit up when red square is at xMax (d19)
---- LED 7 lit up when red square is at y = 0
---- LED 8 lit up when red square is at yMax (d14) 

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
           SW: in STD_LOGIC_VECTOR(4 downto 0); 
           LED: out STD_LOGIC_VECTOR(8 downto 0);
           
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
           ACL_MISO: in STD_LOGIC; -- Master Input, Slave Output. SPI serial data output.
           ACL_MOSI: out STD_LOGIC; -- Master Output, Slave Input. SPI serial data input.
           ACL_SCLK: out STD_LOGIC; -- SPI Communications Clock
           ACL_CSN: out STD_LOGIC  -- SPI Chip Select, Active Low. Must be low during SPI communications.
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


    --ACCEL SPI Data
    signal DATA_X:  std_logic_vector(7 downto 0); --- 8-bit value from register address 0x08 of the accelerometer used to determine up/down movement of red square
    signal DATA_Y :  std_logic_vector(7 downto 0); --- 8-bit value from register address 0x09 of the accelerometer used to determine left/right movement of red square
    signal DATA_Z :  std_logic_vector(7 downto 0); --- 8-bit value from register address 0x0A of accelerometer not used for red square movement
    signal ID_AD :  std_logic_vector(7 downto 0); --- 8-bit value, the result of reading from register address 0x00 of the accelerometer. This value should always read 0xAD (to know it's an Analog Devices device)
    signal ID_1D :  std_logic_vector(7 downto 0); --- 8-bit value, the result of reading from register address 0x01 of the accelerometer. This value should always read 0x1D

    -- ACCEL movements signals
    signal right_tilt_trigger: std_logic;
    signal left_tilt_trigger: std_logic;
    signal down_tilt_trigger: std_logic;
    signal up_tilt_trigger: std_logic;
    
    signal right_tilt_trigger_prev: std_logic;
    signal left_tilt_trigger_prev: std_logic;
    signal down_tilt_trigger_prev: std_logic;
    signal up_tilt_trigger_prev: std_logic;
    
    signal left_tilt_event: std_logic;
    signal right_tilt_event: std_logic;
    signal down_tilt_event: std_logic;
    signal up_tilt_event: std_logic;
    
    
begin
 -- switch 0 is reset
   reset <= SW(0);     
   
 -- LED on when SW is on
    LED(4 downto 0) <= SW;
        

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
     
     
    -------------------------------------------------------------------------------------------------
    ------------------------ Accelerator tilt up/down/left/right-------------------------------------
    -------------------------------------------------------------------------------------------------
    ---- I observed that DATA_Y is 0x02 at balance ----
    --- when I tilt right, the first 4 MSB changes from 0 to B -->  E
    --- when I tilt left, the first 4 MSB changes from 0 to 1 --> 4
    right_tilt_trigger <= '1' when DATA_Y(7 downto 4) = "1110"  -- E
                                    or DATA_Y(7 downto 4) = "1101" --D
                                    or DATA_Y(7 downto 4) = "1100" --C
                                    or DATA_Y(7 downto 4) = "1011" -- B
                        else '0';
    left_tilt_trigger <= '1' when DATA_Y(7 downto 4) = "0001"  -- 1
                                    or DATA_Y(7 downto 4) = "0010" --2
                                    or DATA_Y(7 downto 4) = "0011" --3
                                    or DATA_Y(7 downto 4) = "0100" -- 4
                          else '0';
                                      
                         
    ---- I observed that DATA_X is 0xFC at balance ----
    --- when I tilt up, the first 4 MSB changes from F to B -->  E
    --- when I tilt down, the first 4 MSB changes from F to 1 --> 4
    down_tilt_trigger <= '1' when DATA_X(7 downto 4) = "0001"  -- 1
                                    or DATA_X(7 downto 4) = "0010" --2
                                    or DATA_X(7 downto 4) = "0011" --3
                                    or DATA_X(7 downto 4) = "0100" -- 4
                          else '0';    
    up_tilt_trigger <= '1' when DATA_X(7 downto 4) = "1110"  -- E
                                    or DATA_X(7 downto 4) = "1101" --D
                                    or DATA_X(7 downto 4) = "1100" --C
                                    or DATA_X(7 downto 4) = "1011" -- B
                        else '0';


    --- Save the previous version of each tilt   
     process(CLK100MHZ, reset)
     begin
        if (reset = '1') then
            left_tilt_trigger_prev <= '0';
            right_tilt_trigger_prev <= '0';
            down_tilt_trigger_prev <= '0';
            up_tilt_trigger_prev <= '0';
        elsif (rising_edge(CLK100MHZ)) then
            left_tilt_trigger_prev <= left_tilt_trigger; 
            right_tilt_trigger_prev <= right_tilt_trigger;
            down_tilt_trigger_prev <= down_tilt_trigger; 
            up_tilt_trigger_prev <= up_tilt_trigger;
        end if;    
     end process;
    -- tilt event happens when the trigger value is different than the previous trigger value
    left_tilt_event <= left_tilt_trigger and not left_tilt_trigger_prev;
    right_tilt_event <= right_tilt_trigger and not right_tilt_trigger_prev;
    down_tilt_event <= down_tilt_trigger and not down_tilt_trigger_prev;
    up_tilt_event <= up_tilt_trigger and not up_tilt_trigger_prev;
    
       
    -- Design a process for a 8-bits counter with an enable that counts everytime the enable goes high
    -- When buttons is press, it set the location for the red square
    -- verical count and horizontal count is set to 0 when reset switch is switch on
    btn_counter: process(CLK100MHZ, reset)
    begin
        if(reset = '1') then                    -- verical count and horizontal count is set to 0 when reset switch is switch on
            hcnt <= (others => '0');
            vcnt <= (others => '0');
         elsif(rising_edge(CLK100MHZ)) then 
            -- Up/ Down movemoment of the red square         
            if(vcnt >= VMax) then               -- set vertical counter to 0 when it reach the max value which is 15
                vcnt <= (others => '0');
            else
                -- SW(1) goes low 
                -- BUTTONS UP/ DOWN to control the movement of the red square to left/ right
                if(SW(1) = '0') then               
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
               -- SW(1) goes high                 
               -- ACCELERATOR move up/ down when the board is tilt up/ down
               else 
                    if(up_tilt_event = '1') then
                        if(vcnt = "00000000") then
                            vcnt <= VMax - 1;
                        else
                            vcnt <= vcnt - 1;               
                        end if;
                    elsif(down_tilt_event = '1') then
                        vcnt <= vcnt +1;               
                    else
                        vcnt <= vcnt;
                    end if;  
                 end if;                
            end if;
             
            -- Move left/ right of the red square
            if(hcnt >= HMax) then       -- set horizontal counter to 0 when it reaches its max which is 20
                 hcnt <= (others => '0');
             else
                -- SW(1) goes low
                -- BUTTON LEFT/RIGHT to control the movement of the red square left/ right
                if(SW(1)= '0') then
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
                -- SW(1) goes high
                -- ACCELERATOR moves left/ right               
                else                 
                    if(left_tilt_event = '1') then
                        if(hcnt = "00000000") then
                            hcnt <= HMax - 1;
                        else
                            hcnt <= hcnt - 1;               
                        end if;
                    elsif(right_tilt_event = '1') then
                        hcnt <= hcnt +1;               
                    else
                        hcnt <= hcnt;
                    end if;  
                end if; 
             end if; 
         end if;  -- end if(reset = '1') then
                                            
    end process btn_counter;
    
    
    -- LED 5 lit up when red square is at x = 0
    -- LED 6 lit up when red square is at xMax (d19)
    -- LED 7 lit up when red square is at y = 0
    -- LED 8 lit up when red square is at yMax (d14)
    LED(5) <=  '1' when hcnt = x"00" else '0' ;
    LED(6) <=  '1' when hcnt = x"13" else '0' ;
    LED(7) <=  '1' when vcnt = x"00" else '0' ;
    LED(8) <= '1' when vcnt = x"0E" else '0' ;

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
 
    
    -- SW(4:3) of '00' shows the values of register 0x01 on 7-segment displays 7 and 6 and values of register 0x00 on display 5 and 4
    -- SW(4:3) of '01' shows the value of register 0x08 on display 5 and 4 and should have all zeros on display 6 and 7
    -- SW(4:3) of '10' shows the value of register 0x09 on display 5 and 4 and should have all zeros on display 6 and 7
    -- SW(4:3) of '11' shows the value of register 0x0A on display 5 and 5 and should have all zeros on display 6 and 7

    --- I just want to see DATA_X and DATA_Y values movement at the sametime
        -- SW(2) goes high when SW(4:3) goes low shows the DATA_X and DATA_Y at the seg-7 
        -- char4 and char5 shows the value of DATA_X
        -- char6 and char7 shows the value of DATA_Y                      
    
    process(SW(4), SW(3), SW(2),ID_AD, ID_1D,DATA_X, DATA_Y, DATA_Z)
    begin
        if (SW(4) = '0' and SW(3) = '0' and SW(2) = '0') then
            char4 <= ID_AD(3 downto 0); 
            char5 <= ID_AD(7 downto 4); 
            char6 <= ID_1D(3 downto 0);
            char7 <= ID_1D(7 downto 4);
        elsif ((SW(4) = '0' and SW(3) = '1'  and SW(2) = '0') or (SW(4) = '0' and SW(3) = '1'  and SW(2) = '1')) then
            char4 <= DATA_X(3 downto 0);
            char5 <= DATA_X(7 downto 4);
            char6 <= (others => '0');
            char7 <= (others => '0');
         elsif ((SW(4) = '1' and SW(3) = '0'  and SW(2) = '0') or (SW(4) = '1' and SW(3) = '0'  and SW(2) = '1')) then
            char4 <= DATA_Y(3 downto 0);
            char5 <= DATA_Y(7 downto 4);
            char6 <= (others => '0');
            char7 <= (others => '0');                 
        elsif (SW(4) = '0' and SW(3) = '0' and SW(2) = '1') then
            char4 <= DATA_Y(3 downto 0);
            char5 <= DATA_Y(7 downto 4);
            char6 <= DATA_X(3 downto 0);
            char7 <= DATA_X(7 downto 4);
        else
            char4 <= DATA_Z(3 downto 0);
            char5 <= DATA_Z(7 downto 4);
            char6 <= (others => '0');
            char7 <= (others => '0');
        end if;
    end process;
    

  
end Behavioral;
