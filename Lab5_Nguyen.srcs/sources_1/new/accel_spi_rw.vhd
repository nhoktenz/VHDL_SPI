----------------------------------------------------------------------------------
-- Thuong Nguyen 
-- Accellerator ADXL362
-- datasheet: https://www.analog.com/media/en/technical-documentation/data-sheets/adxl362.pdf 
-- 0x0A : write register
-- 0x0B: read register
-- Address 0x00 to Address 0x2E are for customer access, as described in the register map. 
-- Address 0x2F to Address 0x3F are reserved for factory use

----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.ALL;

entity accel_spi_rw is
Port ( clk : in STD_LOGIC; 
      reset : in STD_LOGIC; 
      --Values from accelerometer used for movement and display 
      DATA_X : out STD_LOGIC_VECTOR(7 downto 0); 
      DATA_Y : out STD_LOGIC_VECTOR(7 downto 0); 
      DATA_Z : out STD_LOGIC_VECTOR(7 downto 0); 
      ID_AD : out STD_LOGIC_VECTOR(7 downto 0); 
      ID_1D : out STD_LOGIC_VECTOR(7 downto 0); 
      --SPI Signals between FPGA and accelerometer 
      CSb : out STD_LOGIC; 
      MOSI : out STD_LOGIC; 
      SCLK : out STD_LOGIC; 
      MISO : in STD_LOGIC); 
end accel_spi_rw;

architecture Behavioral of accel_spi_rw is
    signal MaxCounter1MHz : unsigned(26 downto 0);                 -- maxium counter to match to the MaxCount from pulseGenerator
    signal Pulse1MHz : std_logic;                                  -- pulse out every 1MHz
     
    signal toSPIbytes: std_logic_vector(23 downto 0);          -- 24-bit register
    signal SPIstart: std_logic; 
    signal SPIdone: std_logic;                                 -- transition input signal for the command FSM state machine
    signal timerDone: std_logic;
    signal timerStart: std_logic;
    signal timerMax: unsigned(19 downto 0);                 -- max Counter
    signal cntr: unsigned(19 downto 0);
    signal sclkCntr: unsigned(4 downto 0);                 -- this counter is increment until it reach 24
    
    signal sig24bitMosi: std_logic_vector(23 downto 0);     -- use in parallel-to-serial process
    signal sig24bitMiso: std_logic_vector(23 downto 0);     -- use in serial-to-parallel process
    
    signal dataAD: std_logic_vector(7 downto 0);    -- 8-bit register capture value for ID_AD
    signal dataID: std_logic_vector(7 downto 0);    -- 8-bit register capture value for ID_1D
    signal dataX: std_logic_vector(7 downto 0);    -- 8-bit register capture value for X
    signal dataY: std_logic_vector(7 downto 0);    -- 8-bit register capture value for Y
    signal dataZ: std_logic_vector(7 downto 0);    -- 8-bit register capture value for Z
    
    

type commandFSM is (
    idle,
    writeAddr2D,
    doneStartup,
    readAddr00,
    captureID_AD,
    readAddr01,
    captureID_1D,
    readAddr08,
    captureX,
    readAddr09,
    captureY,
    readAddr0A,
    captureZ
);

signal Moore_state_commandFSM: commandFSM;
--signal next_Moore_state_commandFSM: commandFSM;

type spiFSM is (
    idle,
    setCSlow,
    sclkHi,
    sclkLo,
    wait100ms,
    setCShi,
    checkSclkCntr,
    incSclkCntr
);

signal Moore_state_spiFSM: spiFSM;
--signal next_Moore_state_spiFSM: spiFSM;


begin
    -----------------------------------------------------
    ---------------- Command FSM ------------------------
    -----------------------------------------------------
    CommandFSMState: process(reset, clk)
    begin    
         if(reset = '1') then
            Moore_state_commandFSM <= idle;
        elsif (rising_edge(clk)) then
            case Moore_state_commandFSM is
                when idle =>                   
                    Moore_state_commandFSM <= writeAddr2D;
                 when writeAddr2D =>
                    if (SPIdone = '1') then
                        Moore_state_commandFSM <= doneStartup;
                    else
                        Moore_state_commandFSM <= writeAddr2D;
                    end if;
                 when doneStartup =>
                    Moore_state_commandFSM <= readAddr00;
                 when readAddr00 =>
                    if (SPIdone = '1') then
                        Moore_state_commandFSM <= captureID_AD;
                    else
                        Moore_state_commandFSM <= readAddr00;
                    end if;
                  when captureID_AD =>
                    Moore_state_commandFSM <= readAddr01;
                  when readAddr01 =>
                    if (SPIdone = '1') then
                        Moore_state_commandFSM <= captureID_1D;
                    else
                        Moore_state_commandFSM <= readAddr01;
                    end if;
                when captureID_1D =>
                    Moore_state_commandFSM <= readAddr08;
               when readAddr08 =>
                    if (SPIdone = '1') then
                        Moore_state_commandFSM <= captureX;
                    else
                        Moore_state_commandFSM <= readAddr08;
                    end if;
                when captureX =>
                    Moore_state_commandFSM <= readAddr09;
                when readAddr09 =>
                    if (SPIdone = '1') then
                        Moore_state_commandFSM <= captureY;
                    else
                        Moore_state_commandFSM <= readAddr09;
                    end if; 
                when captureY =>
                    Moore_state_commandFSM <= readAddr0A;
                when readAddr0A =>
                    if (SPIdone = '1') then
                        Moore_state_commandFSM <= captureZ;
                    else
                        Moore_state_commandFSM <= readAddr0A;
                    end if;
                when captureZ =>
                    Moore_state_commandFSM <= readAddr00;
            end case;
        end if;        
    end process CommandFSMState;
    
    
    SPIStart <= '1' when Moore_state_commandFSM = idle 
                      or Moore_state_commandFSM = doneStartup
                      or Moore_state_commandFSM = captureID_AD
                      or Moore_state_commandFSM = captureID_1D
                      or Moore_state_commandFSM = captureX
                      or Moore_state_commandFSM = captureY
                      or Moore_state_commandFSM = captureZ
             else '0';
             
             
   with Moore_state_commandFSM select
   toSPIbytes <= x"0A2D02" when idle,
                 --x"0B0000" when writeAddr2D,
                 --x"0B0000" when doneStartup, 
                 --x"0B0000" when readAddr00, 
                 x"0B0100" when captureID_AD,
                 --x"0B0000" when readAddr01,
                 x"0B0800" when captureID_1D,
                 --x"0B0000" when readAddr08,
                 x"0B0900" when captureX,
                 --x"0B0000" when readAddr09,
                 x"0B0A00" when captureY,
                 --x"0B0000" when readAddr0A,
                 --x"0B0000" when captureZ,
                 x"0B0000" when others;
                         
 
    -----------------------------------------------------
    -------------------- SPI FSM-------------------------
    -----------------------------------------------------
    SpiFSMState: process(reset, clk)
    begin
        if(reset = '1') then
            Moore_state_spiFSM <= idle;
        elsif (rising_edge(clk)) then
            case Moore_state_spiFSM is
            when idle =>
                if SPIstart = '1' then
                    Moore_state_spiFSM <= setCSlow;
                else
                    Moore_state_spiFSM <= idle;
                end if;
            when setCSlow =>
                if timerDone = '1' then
                    Moore_state_spiFSM <= sclkHi;
                else
                    Moore_state_spiFSM <= setCSlow;
                end if;
            when sclkHi =>
                if timerDone = '1' then
                    Moore_state_spiFSM <= sclkLo;
                else
                    Moore_state_spiFSM <= sclkHi;
                end if;
             when sclkLo =>
                if timerDone = '1' then
                    Moore_state_spiFSM <= incSclkCntr;
                else
                    Moore_state_spiFSM <= sclkLo;
                end if;
             when incSclkCntr =>  
                Moore_state_spiFSM <= checkSclkCntr;
             when checkSclkCntr =>
                if sclkCntr = 24 then
                    Moore_state_spiFSM <= setCShi;
                else
                    Moore_state_spiFSM <= sclkHi;
                end if;
             when setCShi => 
                    Moore_state_spiFSM <= wait100ms;
             when wait100ms =>
                if timerDone = '1' then   --- timerDone goes high and SPIdone signal goes high
                    Moore_state_spiFSM <= idle;
                else
                    Moore_state_spiFSM <= wait100ms;
                end if;
            end case; 
        end if;                    
    end process SpiFSMState;
    
    CSb <= '1' when Moore_state_spiFSM = idle
                    or Moore_state_spiFSM = setCShi
                    or Moore_state_spiFSM = wait100ms
          else '0';
    
    SCLK <= '1' when Moore_state_spiFSM = sclkHi else '0';
          
    timerStart <= '1' when Moore_state_spiFSM = setCSlow
                        or Moore_state_spiFSM = sclkHi
                        or Moore_state_spiFSM = sclkLo
                        or Moore_state_spiFSM = wait100ms
           else '0';
           
           
    SPIdone <= '1' when Moore_state_spiFSM = wait100ms and timerDone = '1' else '0';
           
    with Moore_state_spiFSM select
        timerMax <= to_unsigned(19,20) when setCSlow,
                    to_unsigned(49,20) when sclkHi, 
                    to_unsigned(49,20) when sclkLo,
                    to_unsigned(1000000,20) when wait100ms,
                    to_unsigned(0,20) when others;   
    
   -----------------------------------------------------
   --------------- Timer for FSM process ---------------          
   -----------------------------------------------------
   timerForFSM: process(reset,clk)
   begin
        if(reset = '1') then
            cntr <= (others => '0');
        elsif(rising_edge(clk)) then
            if(timerStart = '1') then
                if(cntr < timerMax) then
                    cntr <= cntr + 1;
                --elsif (cntr = timerMax) then
                --    cntr <= (others => '0');
                else
                    --cntr <= cntr;
                    cntr <= (others => '0');
                end if;
           else
            --cntr <= cntr;
            cntr <= (others => '0');
          end if;
      end if;
 end process timerForFSM;
 timerDone <= '1' when cntr = timerMax else '0';
 
 -----------------------------------------------------
 --------------------- SCLK Counter ------------------
 -----------------------------------------------------
 --maxCounter1MHz <= "000000000000000000001100100";  -- binary value for 100 to make 1MHz pulse
 --pulse_1MHz: entity work.pulseGenerator port map ( clk => clk, reset => reset, maxCount => MaxCounter1MHz, pulseOut => Pulse1MHz);
 
 sclkCounter: process (reset, clk)
 begin
     if(reset = '1') then
          sclkCntr <= (others => '0');
     elsif(rising_edge(clk)) then
           if  (Moore_state_spiFSM = wait100ms)  then-- reset sclkCntr when SPI FMS is done
                sclkCntr <= to_unsigned(0,5);
            --elsif (Pulse1MHz = '1') then      
            elsif (Moore_state_spiFSM = incSclkCntr) then -- incease sclkCntr in the incSclkCntr state 
                sclkCntr <= sclkCntr + 1;             -- increase the sclkCntr everytime 1MHz pulse is high
            else
                sclkCntr <= sclkCntr;
            end if;        
     end if;   
 end process sclkCounter;

 
 -----------------------------------------------------
 --- Parallel-To-Serial -----
 -----------------------------------------------------
 parallelToSerial: process(reset,clk)
 begin
     if(reset = '1') then
        sig24bitMosi <= (others => '0');
      elsif(rising_edge(clk)) then
        if(SPIstart = '1') then                 -- load toSPIbytes into a 24-bit shift reguster when SPIstart pulses high
            sig24bitMosi <= toSPIbytes;         
        elsif (Moore_state_spiFSM = sclkHi and timerDone = '1') then   -- when the spiFSM is in state sclkHi and timerDone goes hight
           sig24bitMosi <= sig24bitMosi (sig24bitMosi'left-1 downto 0) & '0';      -- cycling shift the 24-bit shift register one bit to the left             
        else
             sig24bitMosi <= sig24bitMosi;
        end if;
        
      end if;
 end process parallelToSerial;
 MOSI <= sig24bitMosi(23);          -- the MSB of the 24-bit shift register becomes the MOSI output
 
 -----------------------------------------------------
 ---- Serial-To-Parallel ------
 -----------------------------------------------------
 serialToParallel: process(reset, clk)
 begin
     if(reset = '1') then
        sig24bitMiso <= (others => '0');
        dataAD <= (others => '0');
        dataID <= (others => '0');
        dataX <= (others => '0');
        dataY <= (others => '0');
        dataZ <= (others => '0');
      elsif(rising_edge(clk)) then
        if (Moore_state_spiFSM = checkSclkCntr and sclkCntr < 24 ) then --
            sig24bitMiso <= sig24bitMiso (sig24bitMiso'left-1 downto 0) & MISO;  -- shift in the MISO signal into the LSB of the register when SPI FSM is in the checkSclkCntr
            
        else
            sig24bitMiso <= sig24bitMiso;
        end if;
        
        if(Moore_state_commandFSM = captureID_AD) then
                dataAD <= sig24bitMiso(7 downto 0);
            elsif (Moore_state_commandFSM = captureID_1D) then
                dataID <= sig24bitMiso(7 downto 0);
            elsif (Moore_state_commandFSM = captureX) then
                dataX <= sig24bitMiso(7 downto 0);
            elsif (Moore_state_commandFSM = captureY) then
                dataY <= sig24bitMiso(7 downto 0);
            elsif (Moore_state_commandFSM = captureZ) then
                dataZ <= sig24bitMiso(7 downto 0);
            else
                dataAD <= dataAD;
                dataID <= dataID; 
                dataX <= dataX;
                dataY <= dataY;
                dataZ <= dataZ;
            end if;
     end if;
 end process serialToParallel;
 
  DATA_X <= dataX;
  DATA_Y <= dataY;
  DATA_Z <= dataZ;
  ID_AD <= dataAD; 
  ID_1D <= dataID; 
 
end Behavioral;
