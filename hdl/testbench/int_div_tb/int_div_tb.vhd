-------------------------------------------------------------------------------
-- Title      : Integer Divider Testbench
-- Project    :
-------------------------------------------------------------------------------
-- File       : int_div_tb.vhd
-- Author     : João Victor Santos  <joao.ssantos@lnls.br>
-- Company    : CNPEM
-- Created    : 2025-05-06
-- Last update: 2025-15-06
-- Platform   : Simulation
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: Testbench for validanting the signed iterative divider module
-------------------------------------------------------------------------------
-- Copyright (c) 2025 CNPEM
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2025-05-06  1.0      joao.ssantos    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity int_div_tb is
  generic (
  TB_BIT_WIDTH : natural := 32
  );
end entity;

architecture sim of int_div_tb is
  -- Clock and control signals
  signal clk     : std_logic := '0';
  signal rst_n   : std_logic := '0';
  signal valid_i : std_logic := '0';
  signal valid_8_i : std_logic := '0';


  -- Input operands
  signal a_i     : signed(TB_BIT_WIDTH-1 downto 0);
  signal b_i     : signed(TB_BIT_WIDTH-1 downto 0);
  signal a_8_i     : signed(7 downto 0);
  signal b_8_i     : signed(7 downto 0);

  -- Output signals
  signal res_o   : signed(TB_BIT_WIDTH-1 downto 0);
  signal rem_o   : signed(TB_BIT_WIDTH-1 downto 0);
  signal err_o   : std_logic;
  signal busy_o  : std_logic;
  signal ovf_o   : std_logic;
  signal valid_o : std_logic;
  signal res_8_o   : signed(7 downto 0);
  signal rem_8_o   : signed(7 downto 0);
  signal err_8_o   : std_logic;
  signal busy_8_o  : std_logic;
  signal ovf_8_o   : std_logic;
  signal valid_8_o : std_logic;


  -- Wait for a number of clock cycles
  procedure f_wait_cycles(signal clk : in std_logic; constant cycles : natural) is
    begin
      for i in 1 to cycles loop
        wait until rising_edge(clk);
    end loop;
  end procedure;

  -- Wait until valid_o becomes '1' or timeout
  procedure f_wait_valid_o(signal clk : in std_logic;
                          signal valid_o : in std_logic;
                          constant max_cycles : natural := 100) is
    variable count : natural := 0;
    begin
        while valid_o = '0' loop
        wait until rising_edge(clk);
        count := count + 1;
        assert count < max_cycles
          report "Timeout: valid_o did not go high after " & integer'image(max_cycles) & " cycles."
          severity failure;
        end loop;
  end procedure;

  begin

  -- Divider instance for generic width (e.g., 32 bits)
  div_cmp : entity work.int_div
    generic map (
      g_BIT_WIDTH => TB_BIT_WIDTH
      )
    port map (
      clk_i    => clk,
      rst_n_i  => rst_n,
      a_i      => a_i,
      b_i      => b_i,
      valid_i  => valid_i,
      res_o    => res_o,
      rem_o    => rem_o,
      err_o    => err_o,
      ovf_o    => ovf_o,
      busy_o   => busy_o,
      valid_o  => valid_o
  );

  -- Divider instance for 8-bit
  div_cmp2 : entity work.int_div
    generic map (
      g_BIT_WIDTH => 8
    )
    port map (
      clk_i    => clk,
      rst_n_i  => rst_n,
      a_i      => a_8_i,
      b_i      => b_8_i,
      valid_i  => valid_8_i,
      res_o    => res_8_o,
      rem_o    => rem_8_o,
      err_o    => err_8_o,
      ovf_o    => ovf_8_o,
      busy_o   => busy_8_o,
      valid_o  => valid_8_o
  );


-- Clock process
process
  begin
    loop
        clk <= '0'; wait for 5 ns;
        clk <= '1'; wait for 5 ns;
  end loop;
end process;

process
  variable expected_quotient : integer;
  variable expected_remainder : integer;

  variable seed1, seed2 : integer := 1;
  variable seed3, seed4 : integer := 1;
  variable rand_a, rand_b : real;
  variable int_a, int_b : integer;
  begin
    -- Reset
    rst_n <= '0';
    f_wait_cycles(clk, 2);
    rst_n <= '1';
    f_wait_cycles(clk, 1);


    ---------------------------------------------------------------------------
    -- Exhaustive testing for all 8-bit signed input combinations
    ---------------------------------------------------------------------------
    for dividend in -128 to 127 loop
      for divisor in -128 to 127 loop
        a_8_i <= to_signed(dividend, 8);
        b_8_i <= to_signed(divisor, 8);

        valid_8_i <= '1';
        f_wait_cycles(clk, 1);
        valid_8_i <= '0';

        f_wait_valid_o(clk, valid_8_o);

        --- Division by zero check
        if divisor = 0 then
          assert err_8_o = '1'
            report "8 bits: Test case failed: division by zero not detected"
            severity failure;

        -- Overflow case: -128 / -1 exceeds 8-bit signed range
        elsif dividend = -128 and divisor = -1 then
          assert ovf_8_o = '1'
            report "FAILED: Overflow not detected for -128 / -1"
            severity failure;

        -- Normal case
        else
          expected_quotient := dividend / divisor;
          expected_remainder := dividend rem divisor;

          assert res_8_o = to_signed(expected_quotient, 8)
            report "FAILED: " & integer'image(dividend) & " / " & integer'image(divisor) &
            " => Wrong quotient. Expected: " & integer'image(expected_quotient) &
            " Got: " & integer'image(to_integer(res_8_o))
            severity failure;

          assert rem_8_o = to_signed(expected_remainder, 8)
            report "FAILED: " & integer'image(dividend) & " mod " & integer'image(divisor) &
            " => Wrong remainder. Expected: " & integer'image(expected_remainder) &
            " Got: " & integer'image(to_integer(rem_8_o))
            severity failure;

          assert err_8_o = '0'
            report "FAILED: Unexpected error flag for " & integer'image(dividend) & " / " & integer'image(divisor)
            severity failure;

          assert ovf_8_o = '0'
            report "FAILED: Unexpected overflow flag for " & integer'image(dividend) & " / " & integer'image(divisor)
            severity failure;
        end if;
        end loop;
    end loop;

    report "All 8-bit division cases passed successfully.";


    ---------------------------------------------------------------------------
    -- Randomized testing for 32-bit width using 50,000 samples
    ---------------------------------------------------------------------------
    for i in 1 to 50000 loop
      uniform(seed1, seed2, rand_a);
      uniform(seed3, seed4, rand_b);
      int_a := integer(round(rand_a * real(2**31 - 1))) - (2**30);
      int_b := integer(round(rand_a * real(2**31 - 1))) - (2**30);


      f_wait_cycles(clk, 1);
      a_i <= to_signed(int_a, TB_BIT_WIDTH);
      b_i <= to_signed(int_b, TB_BIT_WIDTH);

      valid_i <= '1';
      f_wait_cycles(clk, 1);
      valid_i <= '0';
      f_wait_valid_o(clk, valid_o);


      --- Division by zero check
      if int_b = 0 then
        assert err_o = '1'
          report "Unexpected error flag for: " & integer'image(int_a) & " / " & integer'image(int_b)
          severity failure;

      -- Overflow case: -2**31 / -1 exceeds 32-bit signed range
      elsif int_a = (-1) * (2**31) and int_b = -1 then
        assert ovf_o = '1'
          report "FAILED: Overflow not detected for -2**31 / -1"
          severity failure;

      else
        expected_quotient := int_a / int_b;
        expected_remainder := int_a rem int_b;

        assert res_o = to_signed(expected_quotient, 32)
          report "FAILED (div " & integer'image(i) & "): " &
          integer'image(int_a) & " / " & integer'image(int_b) &
          " => Quotient mismatch. Got: " & integer'image(to_integer(res_o)) &
          ", Expected: " & integer'image(expected_quotient)
          severity failure;

        assert rem_o = to_signed(expected_remainder, TB_BIT_WIDTH)
          report "FAILED (div " & integer'image(i) & "): " &
          integer'image(int_a) & " rem " & integer'image(int_b) &
          " => Remainder mismatch. Got: " & integer'image(to_integer(rem_o)) &
          ", Expected: " & integer'image(expected_remainder)
          severity failure;

        assert err_o = '0'
          report "FAILED (div " & integer'image(i) & "): Unexpected error flag for " &
          integer'image(int_a) & " / " & integer'image(int_b)
          severity failure;

        assert ovf_o = '0'
          report "FAILED (div " & integer'image(i) & "): Unexpected overflow flag for " &
          integer'image(int_a) & " / " & integer'image(int_b)
          severity failure;
      end if;
    end loop;

    report "All 32-bit randomized test cases passed (50,000 total).";
    std.env.finish;
  end process;
end architecture;

