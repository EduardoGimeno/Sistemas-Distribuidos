# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: actor.exs
# FECHA: 2 de noviembre de 2019
# TIEMPO: 5 horas
# DESCRIPCION: Código de los lectores y escritores
defmodule Actor do

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
    def shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug) do
        receive do
            {:read, :clock, pid} -> send(pid, {:clock, clock})
                                    shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:read, :lrd, pid} ->   send(pid, {:lrd, lrd})
                                    shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:read, :op_type, pid} ->   send(pid, {:op_type, op_type})
                                        shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:read, :cs_state, pid} ->  send(pid, {:cs_state, cs_state})
                                        shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:read, :waiting_from, pid} ->  send(pid, {:waiting_from, waiting_from})
                                            shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:read, :perm_delayed, pid} ->  send(pid, {:perm_delayed, perm_delayed})
                                            shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)
                                                
            {:read, :op_lrd, pid} ->    send(pid, {:op_lrd, op_type, lrd})
                                        shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:write, :clock, value} ->  if (debug) do IO.puts("CLOCK: " <> to_string(value)) end
                                        shared_data(value, lrd, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:write, :lrd, value} ->    if (debug) do IO.puts("LRD: " <> to_string(value)) end
                                        shared_data(clock, value, op_type, cs_state, waiting_from, perm_delayed, debug)

            {:write, :op_type, value} ->    if (debug) do IO.puts("OP_TYPE: " <> Atom.to_string(value)) end
                                            shared_data(clock, lrd, value, cs_state, waiting_from, perm_delayed, debug)
            
            {:write, :cs_state, value} ->   if (debug) do IO.puts("CS_STATE: " <> Atom.to_string(value)) end
                                            shared_data(clock, lrd, op_type, value, waiting_from, perm_delayed, debug)

            {:write, :waiting_from, value} ->   if (debug) do IO.puts("WAITING_FROM:"); IO.inspect(value) end
                                                shared_data(clock, lrd, op_type, cs_state, value, perm_delayed, debug)

            {:write, :perm_delayed, value} ->   if (debug) do IO.puts("PERM_DELAYED:"); IO.inspect(value) end
                                                shared_data(clock, lrd, op_type, cs_state, waiting_from, value, debug)
        end
    end 
    
    ########################################################################################################
    #                                                                                                      #
    #                                           PRINCIPAL                                                  #
    #                                                                                                      #
    ########################################################################################################
    
    def protocol(rol, pidmutex, pidsd, id, n, actors, repository) do
        
        # Pre Protocol
        IO.puts("-- Pre Protocol --")
        op_type = generar_operacion(rol)
        send(pidmutex, {:wait, self})
        receive do
            {:ok} ->
                send(pidsd, {:write, :cs_state, :trying})
                send(pidsd, {:read, :clock, self})
                receive do
                    {:clock, clock} -> send(pidsd, {:write, :lrd, clock+1})
                end
                waiting_from = for n <- 1..(n+1), do: false
                send(pidsd, {:write, :waiting_from, List.update_at(waiting_from,id-1,&(&1 = true))})
                send(pidsd, {:write, :op_type, op_type})
                send(pidsd, {:read, :lrd, self})
                receive do
                    {:lrd, lrd} ->  Enum.each actors, fn actor ->
                                        send({:request_process,actor},{:request, lrd, id, op_type, node()})
                                        IO.puts("Enviada request a " <> to_string(actor))
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
        IO.puts("-- Sección Crítica --")
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
                    send(pidsd, {:read, :perm_delayed, self})
                    receive do
                        {:perm_delayed, perm_delayed} ->Enum.each perm_delayed, fn delayed ->
                                                            send({:permission_process,delayed},{:grant_permission, id})
                                                            IO.puts("Enviado permission a " <> to_string(delayed))
                                                        end
                                                        send(pidsd, {:write, :perm_delayed, []})
                    end
                    send(pidmutex, {:signal, self})
        end
        
        Process.sleep(round(:rand.uniform(100)/100 * 2000))
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
    
    # Invocar a la operación de cada rol
    def generar_operacion(rol) do
        if (rol == "lector") do
            generar_operacion_lector
        else
            generar_operacion_escritor
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
            {:request, k, j, op_type_r, node_r} -> spawn(fn ->
                                                            send(pidmutex, {:wait, self})
                                                            receive do
                                                                    {:ok} ->
                                                                        IO.puts("Recibida request " <> to_string(j))
                                                                        send(pidsd, {:read, :clock, self})
                                                                        receive do
                                                                            {:clock, clock} ->
                                                                                send(pidsd, {:write, :clock, max(clock,k)})
                                                                                send(pidsd, {:read, :cs_state, self})
                                                                                receive do
                                                                                    {:cs_state, cs_state} ->
                                                                                        send(pidsd, {:read, :op_lrd, self})
                                                                                        receive do
                                                                                            {:op_lrd, op_type, lrd} -> 
                                                                                                priority = (cs_state != :out ) && comprobar_orden_total(id, lrd, j, k) && exclude(op_type,op_type_r)
                                                                                                if priority do
                                                                                                    send(pidsd, {:read, :perm_delayed, self})
                                                                                                    receive do
                                                                                                        {:perm_delayed, perm_delayed} ->
                                                                                                            send(pidsd, {:write, :perm_delayed, perm_delayed ++ [node_r]})
                                                                                                    end
                                                                                                else
                                                                                                    send({:permission_process,node_r},{:grant_permission,id})
                                                                                                    IO.puts("Enviado permission a " <> to_string(node_r))
                                                                                                end
                                                                                        end
                                                                                end
                                                                        end
                                                                        send(pidmutex, {:signal, self})
                                                            end
                                                        end
                                                        )
                                                        request_receiver(pidmutex, pidsd, id)
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
                                                send(pidmutex, {:wait, self})
                                                receive do
                                                    {:ok} ->
                                                        IO.puts("Recibido permission " <> to_string(j))
                                                        send(pidsd, {:read, :waiting_from, self})
                                                        receive do
                                                            {:waiting_from, waiting_from} ->
                                                                waiting_from = List.update_at(waiting_from,j-1,&(&1 = true))
                                                                send(pidsd, {:write, :waiting_from, waiting_from})
                                                                n = length(waiting_from)
                                                                all_done = for n <- 1..(n+1), do: true
                                                                if (waiting_from == all_done) do
                                                                    send(pidprincipal,{:permission_ok})
                                                                end
                                                        end
                                                        send(pidmutex, {:signal, self})
                                                end
                                             end
                                            )
                                            permission_receiver(pidmutex, pidsd, pidprincipal, id)
        end
    end

    ########################################################################################################
    #                                                                                                      #
    #                                           PREVIO                                                     #
    #                                                                                                      #
    ########################################################################################################

    # Inicialización del sistema
    # rol = escritor o lector
    # id = identificador del grupo de procesos
    def init(rol, id) do
        system_nodes = Node.list
        # Obtener lectores y escritores
        actors = Enum.filter(system_nodes, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        # Obtener repositorio
        repository = Enum.filter(system_nodes, fn(x) -> Atom.to_string(x) =~ "repositorio" end)

        n = length(actors)
        waiting_from = for n <- 1..(n+1), do: false
        # Inicializar proceso de datos compartidos
        # clock, lrd, op_type, cs_state, waiting_from, perm_delayed
        pidsd = spawn(Actor, :shared_data, [0, 0, :nil, :out, waiting_from, [], true])

        # Inicializar proceso mutex
        pidmutex = spawn(Actor, :mutex, [1, []])

        # Inicializar proceso receptor request
        pidrequest = spawn(Actor, :request_receiver_init, [pidmutex, pidsd, id])

        pidprincipal = self()

        # Inicializar proceso receptor permission
        pidpermission = spawn(Actor, :permission_receiver_init, [pidmutex, pidsd, pidprincipal, id])

        IO.puts("Empezando en 5 segundos...")
        Process.sleep(5000)
        
        # Inicio del protocolo
        protocol(rol, pidmutex, pidsd, id, n, actors, repository)
    end 
end
