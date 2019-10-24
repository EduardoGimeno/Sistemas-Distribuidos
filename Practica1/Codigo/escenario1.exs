# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: escenario1_Servidor.exs
# FECHA: 8 de octubre de 2019
# TIEMPO: 30 min
# DESCRIPCION: Código del servidor para el escenario 1
defmodule Fib do
	def fibonacci(0), do: 0
	def fibonacci(1), do: 1
	def fibonacci(n) when n >= 2 do
		fibonacci(n - 2) + fibonacci(n - 1)
	end
	def fibonacci_tr(n), do: fibonacci_tr(n, 0, 1)
	defp fibonacci_tr(0, _acc1, _acc2), do: 0
	defp fibonacci_tr(1, _acc1, acc2), do: acc2
	defp fibonacci_tr(n, acc1, acc2) do
		fibonacci_tr(n - 1, acc2, acc1 + acc2)
	end

	@golden_n :math.sqrt(5)
  	def of(n) do
 		(x_of(n) - y_of(n)) / @golden_n
	end
 	defp x_of(n) do
		:math.pow((1 + @golden_n) / 2, n)
	end
	def y_of(n) do
		:math.pow((1 - @golden_n) / 2, n)
	end
end

defmodule Server do
    def listen_client do
        receive do
            {c_pid, :fib, interval, op} -> time1 = :os.system_time(:millisecond)
      						               fibonacci_list = Enum.map(interval, fn(x) -> Fib.fibonacci(x) end)
      							           time2 = :os.system_time(:millisecond)
                                           send(c_pid, {:result, time2 - time1, fibonacci_list})
        end
        listen_client
    end
end
