# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: master.exs
# FECHA: 19 de noviembre de 2019
# TIEMPO: 
# DESCRIPCION: Código del master para la práctica 3

defmodule Master do
    
    # Función que se comunica con los workers y devuelve el resultado al cliente.
    attend_request(client_pid, n, timeout, workers) do
        if (length(workers > 0)) do
            worker = hd(workers)
            send({:worker_process,worker}, {:req, {self, n}})
            receive do
                {res} -> send(client_pid,{:result,res})
                IO.puts("OK: Resultado enviado al cliente")
            after
                timeout ->
                    workers = tl(workers)
                    attend_request(client_pid, n, workers, timeout)
                    IO.puts("ERROR: Timeout vencido. Reintentando...")
            end
        else
            IO.puts("ERROR: Todos los workers han fallado")
        end
    end
    
    # Función que recibe peticiones de los clientes
    master_process(timeout) do
        receive do
            {client_pid, n} ->  workers = Enum.filter(Node.list(), fn(x) -> Atom.to_string(x) =~ "worker"
                                attend_request(client_pid, n, timeout, workers)
        end
        master(timeout)
    end
    
    def init () do
        Process.register(self,:master_process)
        timeout = 25000
        master_process(timeout)
    end
    
end

