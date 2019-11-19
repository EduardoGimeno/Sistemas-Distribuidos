# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: master.exs
# FECHA: 19 de noviembre de 2019
# TIEMPO: 
# DESCRIPCION: Código del master para la práctica 3

defmodule Master do
    
    attend_request(client_pid, n, [worker | workers], timeout, retry_count) do
        if (retry_count > 0) do
            send(worker, {:req, {self, n}})
            receive do
                {res} -> send(client_pid,{:result,res})
                IO.puts("OK: Resultado enviado al cliente")
            after
                timeout -> attend_request(client_pid, n, workers, timeout, retry_count-1)
                IO.puts("ERROR: Timeout vencido. Reintentando...")
            end
        else
            IO.puts("ERROR: Todos los workers han fallado")
        end
    end
    
    master_process(workers, timeout, retry_count) do
        receive do
            {client_pid, n} -> attend_request(client_pid, n, workers, timeout, retry_count)
        end
        master(workers, timeout, retry_count)
    end

    def init () do
        Process.register(self,:master_process)
        timeout = 25000
        retry_count = 10
        workers = Enum.filter(Node.list(), fn(x) -> Atom.to_string(x) =~ "worker"
        master_process(workers, timeout, retry_count)
    end
    
end

