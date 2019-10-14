# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: cliente.exs
# FECHA: 8 de octubre de 2019
# TIEMPO: 1 hora
# DESCRIPCION: Código del cliente
defmodule Cliente do
  def launch_request(pid, op, n) do
	time1 = :os.system_time(:millisecond)
	send(pid, {self, op, 1..36, n})
	receive do 
		{:result, time, l} -> time2 = :os.system_time(:millisecond)
							  IO.inspect(l)
							  IO.inspect("Tiempo de ejecucion terea aislada: #{time}")
							  IO.inspect("Tiempo total de respuesta: #{time2 - time1}")
							  if (time2 - time1) > (time * 1.5), do: IO.puts("Violacion del QoS")
	end
  end

  def launch(pid, op, 1) do
	spawn(Cliente, :launch_request, [pid, op, 1])
  end

  def launch(pid, op, n) when n != 1 do
	spawn(Cliente, :launch_request, [pid, op, n])
	launch(pid, op, n - 1)
  end 
  
  def genera_workload(server_pid, escenario, time) do
	cond do
		time <= 3 ->  launch(server_pid, :fib, 8); Process.sleep(2000)
		time == 4 ->  launch(server_pid, :fib, 8);Process.sleep(round(:rand.uniform(100)/100 * 2000))
		time <= 8 ->  launch(server_pid, :fib, 8);Process.sleep(round(:rand.uniform(100)/1000 * 2000))
		time == 9 -> launch(server_pid, :fib_tr, 8);Process.sleep(round(:rand.uniform(2)/2 * 2000))
	end
  	genera_workload(server_pid, escenario, rem(time + 1, 10))
  end

  def genera_workload(server_pid, escenario) do
  	if escenario == 1 do
		launch(server_pid, :fib, 1)
	else
		launch(server_pid, :fib, 4)
	end
	Process.sleep(2000)
  	genera_workload(server_pid, escenario)
  end
  

  def cliente(server_pid, tipo_escenario) do
  	case tipo_escenario do
		:uno -> genera_workload(server_pid, 1)
		:dos -> genera_workload(server_pid, 2)
		:tres -> genera_workload(server_pid, 3, 1)
	end
  end
end