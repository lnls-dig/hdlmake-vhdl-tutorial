-------------------------------------------------------------------------------
-- Title      : Signed integer divider core
-- Project    :
-------------------------------------------------------------------------------
-- File       : int_div.vhd
-- Author     : João Victor Santos <joao.ssantos@lnls.br>
-- Company    : CNPEM
-- Created    : 2025-05-07
-- Last update: 2025-13-07
-- Platform   : Synthesis
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Iterative divider for signed integers using shift and subtract
-------------------------------------------------------------------------------
-- Copyright (c) 2025
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2025-05-07  1.0       Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity int_div is
  generic (
    g_BIT_WIDTH: natural range 2 to 64 := 8
  );
  port (
    -- Clock input
    clk_i:   in  std_logic;

    -- Reset (active low)
    rst_n_i: in  std_logic;

    -- Numerator
    a_i:     in  signed(g_BIT_WIDTH-1 downto 0);

    -- Denominator
    b_i:     in  signed(g_BIT_WIDTH-1 downto 0);

    -- Input valid signal, will be ignored if the core is busy, should be
    -- pulsed for a single clock cycle
    valid_i: in  std_logic;

    -- Result output
    res_o:   out signed(g_BIT_WIDTH-1 downto 0);

    -- Remainder output
    rem_o:   out signed(g_BIT_WIDTH-1 downto 0);

    -- Error output (division by zero)
    err_o:   out std_logic;

    -- Error output (Overflow)
    ovf_o:   out std_logic;

    -- If it is '1', the core is busy and will not accept new operations
    busy_o:  out std_logic;

    -- Pulses high (for one clock cycle) when the operation is finished
    valid_o: out std_logic
  );
end entity;

architecture rtl of int_div is
  type state_t is (IDLE, BUSY, DONE);
  signal state: state_t := IDLE;

  -- Bit position tracker
  signal counter: integer range 0 to g_BIT_WIDTH := 0;
  -- Stores the absolute values of a_i and b_i as unsigned for processing
  signal dividend_abs, divisor_abs: unsigned(g_BIT_WIDTH-1 downto 0);
  -- Stores the unsigned result of the division
  signal quotient_u: unsigned(g_BIT_WIDTH-1 downto 0);
  -- Stores the partial remainder during the iterative division process
  signal remainder_u: unsigned(g_BIT_WIDTH-1 downto 0);
  -- Stores the expected sign of the final quotient result
  signal result_sign: std_logic;
  -- Stores the expected sign of the final remainder result
  signal rem_sign: std_logic;
  -- Minimum representable signed value
  constant min_signed : signed(0 to g_BIT_WIDTH-1) := (0 => '1', others => '0');

begin
  process(clk_i)
    -- Temporary for next remainder
    variable rem_next : unsigned(g_BIT_WIDTH-1 downto 0);
    -- Temporary for next quotient
    variable quot_next : unsigned(g_BIT_WIDTH-1 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        -- Reset all registers
        state <= IDLE;
        res_o <= (others => '0');
        rem_o <= (others => '0');
        err_o <= '0';
        ovf_o <= '0';
        busy_o <= '0';
        quotient_u <= (others => '0');
        remainder_u <= (others => '0');
        valid_o <= '0';
      else
        case state is
          when IDLE =>
            -- IDLE state: waiting for a valid request
            busy_o <= '0';
            valid_o <= '0';

            -- Request to begin operation
            if valid_i = '1' then
              if b_i = 0 then
                -- Division by zero error
                err_o <= '1';
                valid_o <= '1';
                res_o <= (others => '0');
                rem_o <= (others => '0');

              -- Overflow: result exceeds signed range
              elsif a_i = min_signed and b_i = to_signed(-1, g_BIT_WIDTH) then
                ovf_o <= '1';
                valid_o <= '1';
                res_o <= (others => '0');
                rem_o <= (others => '0');

              else
                -- Valid operation begins
                err_o <= '0';
                ovf_o <= '0';


                -- Convert operands to absolute unsigned values (unsigned) for shift/subtract
                dividend_abs <= unsigned(abs(a_i));
                divisor_abs  <= unsigned(abs(b_i));

                -- Sign of quotient determined by XOR of signs
                result_sign <= a_i(g_BIT_WIDTH-1) xor b_i(g_BIT_WIDTH-1);
                -- Sign of remainder follows the dividend
                rem_sign <= a_i(g_BIT_WIDTH-1);

                -- Initialize internal division registers
                quotient_u <= (others => '0');
                remainder_u <= (others => '0');
                counter <= g_BIT_WIDTH;

                -- Move to BUSY state to begin division
                state <= BUSY;
                busy_o <= '1';
              end if;
            end if;


          when BUSY =>
            -- The output is not ready yet, so valid_o is kept low during this phase
            valid_o <= '0';

            -- shift left current remainder and bring in the next bit of dividend
            rem_next := shift_left(remainder_u, 1);
            rem_next(0) := dividend_abs(counter-1);

            -- Compare partial remainder with divisor
            if rem_next >= divisor_abs then
              -- Subtract divisor and set quotient bit to '1'
              remainder_u <= rem_next - divisor_abs;
              quot_next := shift_left(quotient_u, 1);
              quot_next(0) := '1';
              quotient_u <= quot_next;
            else
              -- Keep remainder and set quotient bit to '0'
              remainder_u <= rem_next;
              quotient_u <= shift_left(quotient_u, 1); -- 0 inserted automatically
            end if;

            -- Decrement counter or finish
            if counter = 1 then
              state <= DONE;
            else
              counter <= counter - 1;
            end if;

          when DONE =>
            -- Apply the correct sign to the final quotient
            busy_o <= '0';

            -- Restore quotient sign
            if result_sign = '1' then
              res_o <= -signed(quotient_u);
            else
              res_o <= signed(quotient_u);
            end if;

            -- Restore remainder sign
            if rem_sign = '1' then
              rem_o <= -signed(remainder_u);
            else
              rem_o <= signed(remainder_u);
            end if;

            -- Result is ready
            valid_o <= '1';
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
