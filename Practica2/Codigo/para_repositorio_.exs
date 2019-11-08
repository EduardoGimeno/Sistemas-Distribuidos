# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: para_repositorio.exs
# FECHA: 2 de noviembre de 2019
# TIEMPO: 3 horas
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
    def shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed) do
        receive do
            {:read, :clock, pid} -> send(pid, {:clock, clock})
                                    shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :lrd, pid} -> send(pid, {:lrd, lrd})
                                    shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :op_type, pid} -> send(pid, {:op_type, op_type})
                                      shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :cs_state, pid} -> send(pid, {:cs_state, cs_state})
                                       shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :waiting_from, pid} -> send(pid, {:waiting_from, waiting_from})
                                           shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:read, :perm_delayed, pid} -> send(pid, {:permissions_received, permissions_received})
                                                   shared_data(clock, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:write, :clock, value} -> shared_data(value, lrd, op_type, cs_state, waiting_from, perm_delayed)

            {:write, :lrd, value} -> shared_data(clock, value, op_type, cs_state, waiting_from, perm_delayed)

            {:write, :op_type, value} -> shared_data(clock, lrd, value, waiting_from, perm_delayed)

            {:write, :waiting_from, value} -> shared_data(clock, lrd, op_type, value, perm_delayed)

            {:write, :perm_delayed, value} -> shared_data(clock, lrd, op_type, waiting_from, value)
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

    def request_receiver(pidmutex, pidsd, id) do
        receive do
            {:request, k, j, op_type_r, id_r} -> spawn(fn -> send(pidmutex, {self, :wait})
                                                             send(pidsd, {:read, :clock, self})
                                                             receive do
                                                                 {:clock, clock} -> 
                                                             end)
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
    def init(id, system_nodes) do
        # Obtener lectores y escritores
        actors = Enum.filter(system_nodes, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        # Obtener repositorio
        repository = Enum.filter(system_nodes, fn(x) -> Atom.to_string(x) =~ "repositorio" end)

        n = length(actors)
        perm_delayed = for n <- 1..n, do: false
        # Inicializar proceso de datos compartidos
        # clock, lrd, op_type, cs_state, waiting_from, permissions_received
        pidsd = spawn(Actor, :shared_data, [0, 0, :nil, :out, 0, perm_delayed])

        # Inicializar proceso mutex
        pidmutex = spawn(Actor, :mutex, [1, []])

        # Inicializar proceso receptor request
        pidrequest = spawn(Actor, :request_receiver_init, [pidmutex, pidsd, id])

        pidprincipal = self()

        # Inicializar proceso receptor permission
        pidpermission = spawn(Actor, :permission_receiver_init, [pidmutex, pidsd, pidprincipal, id])

        # Inicio del protocolo
        protocol(pidmutex, pidsd, id, n, actors, repository)
    end 
end