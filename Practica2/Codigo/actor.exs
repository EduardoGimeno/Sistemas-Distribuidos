# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: actor.exs
# FECHA: 2 de noviembre de 2019
# TIEMPO: 5 horas
# DESCRIPCION: Código de los lectores y escritores
defmodule Actor do

    ########################################################################################################
    #                                                                                                      #
    #                                           PRINCIPAL                                                  #
    #                                                                                                      #
    ########################################################################################################
    
    def protocol(rol, pidmutex, pidsd, id, n, actors, repository) do
        # Pre Protocol
        IO.puts("-- Pre Protocol --")
        send(pidmutex, {:wait, self})
        receive do
            {:ok} ->
                send(pidsd, {:write, :cs_state, :trying})
                send(pidsd, {:read, :clock})
                receive do
                    {:clock, clock} -> send(pidsd, {:write, :lrd, clock+1})
                end
                waiting_from = for n <- 1..n, do: false
                send(pidsd, {:write, :waiting_from, List.update_at(waiting_from,id-1,&(&1 = true))})
                if (rol == "lector") do
                    op_type = generar_operacion_lector
                else
                    op_type = generar_operacion_escritor
                end
                send(pidsd, {:write, :op_type, op_type})
                send(pidsd, {:read, :lrd})
                receive do
                    {:lrd, lrd} ->  Enum.each actors, fn actor ->
                                        send({:request_process,actor},{:request, lrd, id, op_type, node()})
                                    end
                end
                send(pidmutex, {:signal, self})
        end
        receive do
            {:permission_ok} -> send(pidmutex, {:wait, self})
                                receive do
                                    {:ok} -> send(pidsd, {:write, :cs_state, :in})
                                    send(pidmutex, {:signal, self})
                                end
        end
        
        # Sección Crítica
        sc_title = "-- Sección Crítica (" <> to_string(lrd) <> ") --"
        IO.puts(sc_title)
        if (rol == "lector") do
            send({:server,repository}, {op_type, self})
            op_type_s = Atom.to_string(op_type)
            receive do
                {:reply, content} -> IO.puts(op_type_s)
                                     IO.puts(content)
            end
        else
            content = "ESCRITURA " <> to_string(id)
            send({:server,repository}, {op_type, self, content})
            op_type_s = Atom.to_string(op_type)
            receive do
                {:reply, :ok} -> IO.puts(op_type_s)
                                 IO.puts(content)
            end
        end
        
        # Post Protocol
        IO.puts("-- Post Protocol --")
        send(pidmutex, {:wait, self})
        receive do
            {:ok} ->send(pidsd, {:write, :cs_state, :out})
                    send(pidsd, {:read, :perm_delayed})
                    receive do
                        {:perm_delayed, perm_delayed} ->Enum.each perm_delayed, fn delayed ->
                                                            send({:permission_process,delayed},{:grant_permission, id})
                                                        end
                                                        send(pidsd, {:write, :perm_delayed, []})
                    end
                    send(pidmutex, {:signal, self})
        end
        
        protocol(rol,pidmutex,pidsd,id,n,actors,repository)
    end

    ########################################################################################################
    #                                                                                                      #
    #                                           AUXILIARES                                                 #
    #                                                                                                      #
    ########################################################################################################
    
    # Genera una operación aleatoria para el lector
    def generar_operacion_lector do
        random_op = :rand.uniform(3)
        cond do
            random_op == 1 -> :read_resumen
            random_op == 2 -> :read_principal
            random_op == 3 -> :read_entrega
        end
    end

    # Genera una operación aleatoria para el escritor
    def generar_operacion_escritor do
        random_op = :rand.uniform(3)
        cond do
            random_op == 1 -> :update_resumen
            random_op == 2 -> :update_principal
            random_op == 3 -> :update_entrega
        end
    end
    
    # Comprobar el orden total de dos eventos
    def comprobar_orden_total(proc_id, lrd, proc_id_r, lrd_r) do
        cond do
            lrd < lrd_r -> true
            (lrd == lrd_r) and (proc_id < proc_id_r) -> true
            true -> false
        end
    end
    
    # Comprobar la exclusión de dos operaciones
    def exclude(op_type, op_type_r) do
        cond do
            (Atom.to_string(op_type) =~ "read") and (Atom.to_string(op_type_r) =~ "read") -> false
            true -> true
        end
    end
    

    ########################################################################################################
    #                                                                                                      #
    #                                       DATOS COMPARTIDOS                                              #
    #                                                                                                      #
    ########################################################################################################

    # Mutex 
    # counter = contador del mutex
    # waiting = lista de bloqueados
    def mutex(counter, waiting) do
        receive do
            {:wait, pid} -> if counter == 1 do
                                send(pid, {:ok})
                                mutex(0, [])
                            else
                                mutex(counter, [pid])
                            end

            {:signal, pid} -> if length(waiting) == 0 do
                                mutex(1, waiting)
                            else
                                wake = hd(waiting)
                                send(wake, {:ok})
                                mutex(0, [])
                            end
        end
    end
    
    # Datos compartidos entre los procesos de un grupo
    # clock = reloj observado del resto de procesos
    # lrd = reloj propio
    # op_type = operación a ejecutar sobre el repositorio
    # cs_state = estado de acceso a la sección crítica
    # waiting_from = estado de la recepción del permission de cada proceso
    # perm_delayed = lista de procesos a la espera
    def shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed) do
        receive do
            {:read, :clock, pid} -> send(pid, {:clock, clock})
                                    shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :lrd, pid} ->   send(pid, {:lrd, lrd})
                                    shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :op_type, pid} ->   send(pid, {:op_type, op_type})
                                        shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :cs_state, pid} ->  send(pid, {:cs_state, cs_state})
                                        shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :waiting_from, pid} ->  send(pid, {:waiting_from, waiting_from})
                                            shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :perm_delayed, pid} ->  send(pid, {:perm_delayed, perm_delayed})
                                            shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)
                                                
            {:read, :op_lrd, pid} ->    send(pid, {:op_lrd, op_type, lrd})
                                        shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:write, :clock, value} -> shared_data(value, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:write, :lrd, value} -> shared_data(clock, value, op_type, cs_state, waiting_from, perm_delayed)

            {:write, :op_type, value} -> shared_data(clock, lrd, value, cs_state, waiting_from, perm_delayed)
            
            {:write, :cs_state, value} -> shared_data(clock, lrd, op_type, value, waiting_from, perm_delayed)

            {:write, :waiting_from, value} -> shared_data(clock, lrd, op_type, cs_state, value, perm_delayed)

            {:write, :perm_delayed, value} -> shared_data(clock, lrd, op_type, cs_state, waiting_from, value)
        end
    end 

    ########################################################################################################
    #                                                                                                      #
    #                                    REQUEST Y PERMISSION                                              #
    #                                                                                                      #
    ########################################################################################################  

    # Registro proceso receptor request
    # pidmutex = pid proceso mutex
    # pidsd = pid proceso datos compartidos
    # id = identificador del grupo de procesos
    def request_receiver_init(pidmutex, pidsd, id) do
        Process.register(self, :request_process)
        request_receiver(pidmutex, pidsd, id)
    end 
    
    # Proceso receptor request
    def request_receiver(pidmutex, pidsd, id) do
        receive do
            {:request, k, j, op_type_r, node_r} -> spawn(fn ->	send(pidmutex, {self, :wait})
                                                        receive do
                                                            {:ok} ->
                                                                send(pidsd, {:read, :clock, self})
                                                                receive do
                                                                    {:clock, clock} -> send(pidsd, {:write, :clock, max(clock,k)})
                                                                end
                                                                send(pidsd, {:read, :cs:state, self})
                                                                receive do
                                                                    {:cs_state, cs_state} -> send(pidsd, {:read, :op_lrd, self})
                                                                                            receive do
                                                                                                {:op_lrd, op_type, lrd} -> 
                                                                                                                        priority = (cs_state != :out ) && comprobar_orden_total(id, lrd, j, k) && exclude(op_type,op_type_r)
                                                                                                                        if priority
                                                                                                                            send(pidsd, {:read, :perm_delayed, self})
                                                                                                                            receive do
                                                                                                                                {:perm_delayed, perm_delayed} -> send(pidsd, {:write, :perm_delayed, perm_delayed ++ [node_r]})
                                                                                                                            end
                                                                                                                        else
                                                                                                                            send({:permission_process,node_r},{:grant_permission,j})
                                                                                                                        end
                                                                                            end
                                                                end
                                                                send(pidmutex, {self, :wait})
                                                        end
                                                        )
        end
        
    end
    
    # Registro proceso receptor permission
    # pidmutex = pid proceso mutex
    # pidsd = pid proceso datos compartidos
    # pidprincipal = pid proceso principal
    # id = identificador del grupo de procesos
    def permission_receiver_init(pidmutex, pidsd, pidprincipal,	id) do
        Process.register(self, :permission_process)
        permission_receiver(pidmutex, pidsd, pidprincipal, id)
    end
    
    # Proceso receptor permission
    def permission_receiver(pidmutex, pidsd, pidprincipal, id) do
        receive do
            {:grant_permission, j} -> spawn(fn -> 
                                                send(pidmutex, {self, :wait})
                                                receive do
                                                    {:ok} ->
                                                        send(pidsd, {:read, :waiting_from)
                                                        receive do
                                                            {:waiting_from, waiting_from} ->    waiting_from = List.update_at(waiting_from,j-1,&(&1 = true))
                                                                                                send(pidsd, {:write, :waiting_from, waiting_from})
                                                        end
                                                        all_done = for n <- 1..n, do: true
                                                        if (waiting_from == all_done)
                                                            send(pidprincipal,{:permission_ok})
                                                        end
                                                        send(pidmutex, {self, :signal})
                                                end
                                            )
            
        end
    end

    ########################################################################################################
    #                                                                                                      #
    #                                           PREVIO                                                     #
    #                                                                                                      #
    ########################################################################################################

    # Inicialización del sistema
    # id = identificador del grupo de procesos
    # system_nodes = nodos del sistema
    def init(rol, id, system_nodes) do
        # Obtener lectores y escritores
        actors = Enum.filter(system_nodes, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        # Obtener repositorio
        repository = Enum.filter(system_nodes, fn(x) -> Atom.to_string(x) =~ "repositorio" end)

        n = length(actors)
        waiting_from = for n <- 1..n, do: false
        # Inicializar proceso de datos compartidos
        # clock, lrd, op_type, cs_state, waiting_from, permissions_received
        pidsd = spawn(Actor, :shared_data, [0, 0, :nil, :out, waiting_from, []])

        # Inicializar proceso mutex
        pidmutex = spawn(Actor, :mutex, [1, []])

        # Inicializar proceso receptor request
        pidrequest = spawn(Actor, :request_receiver_init, [pidmutex, pidsd, id])

        pidprincipal = self()

        # Inicializar proceso receptor permission
        pidpermission = spawn(Actor, :permission_receiver_init, [pidmutex, pidsd, pidprincipal, id])

        # Inicio del protocolo
        protocol(rol, pidmutex, pidsd, id, n, actors, repository)
    end 
end
