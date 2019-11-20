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

defmodule Worker do
    
	def init do
		Process.sleep(10000)
		worker(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))
	end
		    
	defp worker(op, service_count, k) do
		[new_op, omission] = if rem(service_count, k) == 0 do
			behavioural_probability = :rand.uniform(100)
			cond do
				behavioural_probability >= 90 -> 
					[&System.halt/1, false]
				behavioural_probability >= 70 -> 
					[&Fib.fibonacci/1, false]
				behavioural_probability >=  50 -> 
					[&Fib.of/1, false]
				behavioural_probability >=  30 -> 
					[&Fib.fibonacci_tr/1, true]
				true	-> 
					[&Fib.fibonacci_tr/1, false]
			end
		else
			[op, false]
		end
		receive do
			{:req, {pid, args}} -> if not omission, do: send(pid, op.(args))
		end	
		worker(new_op, rem(service_count + 1, k), k)
	end
end

defmodule Master do
    def listen_client(pool_pid) do
        receive do
            {c_pid, imp, interval, op} -> spawn(fn -> callWorker(pool_pid, c_pid, imp, interval, op) end)
        end
        listen_client(pool_pid)
    end

	def callWorker(pool_pid, c_pid, imp, interval, op) do
		send(pool_pid, {self, :nuevo_worker})
		if imp == :fib do
			receive do
				{:worker, worker_pid} -> Node.spawn(worker_pid, fn -> time1 = :os.system_time(:millisecond)
      						                           				  fibonacci_list = Enum.map(interval, fn(x) -> Fib.fibonacci(x) end)
      							                       				  time2 = :os.system_time(:millisecond)
                                                       				  send(c_pid, {:result, time2 - time1, fibonacci_list})
										 end) 
			end
		else
			receive do
				{:worker, worker_pid} -> Node.spawn(worker_pid, fn -> time1 = :os.system_time(:millisecond)
      						                           				  fibonacci_list = Enum.map(interval, fn(x) -> Fib.fibonacci_tr(x) end)
      							                       				  time2 = :os.system_time(:millisecond)
                                                       				  send(c_pid, {:result, time2 - time1, fibonacci_list})
										 end) 
			end
		end
	end
end

defmodule Pool do
    def listen_master([worker_pid|tail]) do
        receive do
            {server_pid, :nuevo_worker} -> send(server_pid, {:worker, worker_pid}) 
        end
		listen_master(tail++[worker_pid])
    end

	def initPool() do
		filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "worker" end)
		listen_master(filtered_list)
	end
end

defmodule Cliente do

  defp launch(pid, 1, timeout) do
	send(pid, {self, 1500})
	receive do 
		{:result, l} -> IO.puts("OK: Resultado recibido")
	after 
		timeout -> IO.puts("ERROR: Timeout vencido. Reintentando...") 
				   launch(pid, 1, timeout)
	end
  end

  defp launch(pid, n) when n != 1 do
  	if rem(n, 3) == 0, do: number = 100, else: number = 36
	send(pid, {self, :random.uniform(number)})
	receive do
		{:result, l} -> l
	end
	launch(pid, n - 1)
  end 
  
  def genera_workload(server_pid) do
	launch(server_pid, 6 + :random.uniform(2))
	Process.sleep(2000 + :random.uniform(200))
  	genera_workload(server_pid)
  end
 
end