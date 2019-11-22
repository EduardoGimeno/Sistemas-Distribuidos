# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: para_fibonacci.exs
# FECHA: 22 de noviembre de 2019
# TIEMPO: 8 horas
# DESCRIPCION: Código para el escenario 3 de la práctica 1 con detección de fallos

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
		Process.register(self, :worker)
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
			{:req, {pid, args}} -> if not omission, do: send(pid, {:result, op.(args)})
		end	
		worker(new_op, rem(service_count + 1, k), k)
	end
end

defmodule Master do
    def listen_client(pool_pid) do
        receive do
            {c_pid, n} -> if n == 1500 do
								send(c_pid, {:not_supported})
						  else
					      		spawn(fn -> callWorker(pool_pid, c_pid, n) end)
						  end
        end
        listen_client(pool_pid)
    end

	def callWorker(pool_pid, c_pid, n) do
		send(pool_pid, {self, :nuevo_worker})
		receive do
			{:worker, worker_pid} -> send({:worker, worker_pid}, {:req, {c_pid, n}})
		end
	end
end

defmodule Pool do
    def listen_master(worker_list) do
        receive do
            {server_pid, :nuevo_worker} -> worker_pid = hd(worker_list)
										   new_worker_list = tl(worker_list)
										   send(server_pid, {:worker, worker_pid})
										   listen_master(new_worker_list ++ [worker_pid]) 
        end
    end

	def initPool() do
		filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "worker" end)
		listen_master(filtered_list)
	end
end

defmodule Proxy do
	def listen_client(master_pid) do
		receive do
			{c_pid, n} -> spawn(Proxy, :send_request, [c_pid, master_pid, n, 2500, 0, 10]) 
		end
		listen_client(master_pid)
	end

	def send_request(c_pid, master_pid, n, timeout, k, retries) do
		send(master_pid, {self, n})
		receive do
			{:result, l} -> IO.inspect(c_pid, label: "OK: Resultado recibido")
							send(c_pid, {:result, l})
			{:not_supported} -> IO.inspect(c_pid, label: "OK: Operacion no soportada")
								send(c_pid, {:not_supported})
		after
			timeout -> if k <= retries do
				  	 		IO.inspect(c_pid, label: "ERROR: Timeout vencido. Reintentando...") 
				   			send_request(c_pid, master_pid, n, timeout, k+1, retries)
				 	   else
				   			IO.inspect(c_pid, label: "ERROR: Reintentos agotados")
							send(c_pid, {:expired})
				  	   end
		end
    end
end

defmodule Cliente do
  def send_request(proxy_pid, n) do
	send(proxy_pid, {self, n})
	receive do
		{:result, l} -> IO.inspect(self, label: "OK: Resultado recibido")
		{:not_supported} -> IO.inspect(self, label: "ERROR: Operacion no soportada")
		{:expired} -> IO.inspect(self, label: "ERROR: Reintentos agotados")
	end
  end

  defp launch(pid, 1) do
	spawn(Cliente, :send_request, [pid, 1500])
  end

  defp launch(pid, n) when n != 1 do
  	if rem(n, 3) == 0 do 
	  	number = 100 
		spawn(Cliente, :send_request, [pid, :random.uniform(number)])
	else 
		number = 36
		spawn(Cliente, :send_request, [pid, :random.uniform(number)])
	end
	launch(pid, n-1)
  end 
  
  def genera_workload(proxy_pid) do
	launch(proxy_pid, 6 + :random.uniform(2))
	Process.sleep(2000 + :random.uniform(200))
  	genera_workload(proxy_pid)
  end
 
end