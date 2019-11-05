# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: alumno_lector.exs
# FECHA: 2 de noviembre de 2019
# TIEMPO: 15 min
# DESCRIPCION: Código del escritor
defmodule Escritor do

########################################################################################################
#                                                                                                      #
#                                       PREVIO                                                         #
#                                                                                                      #
########################################################################################################
            
    # Cada proceso principal debe conocer los subprocesos encargados de las request y los permissions de los demás
    def begin_protocol(proc_id, total_sistema) do
        IO.puts("START")
        # Inicializar variables que deben conocer desde un inicio los subprocesos encargados de recibir request y permission
        clock = 0
        lrd = clock
        cs_state = :out

        waiting_from = Enum.to_list 1..total_sistema
        waiting_from = List.delete(waiting_from, proc_id)
        
        IO.puts("SPAWN REQUEST Y PERMISSION")
        # Crear subprocesos encargados de recibir request y permission
        rr_pid = spawn(Common, :request, [proc_id, lrd, clock, cs_state, [], :nil, [], true])
        rp_pid = spawn(Common, :permission, [waiting_from, waiting_from, self])

        # Enviar al resto de procesos princiaples los pids de los subprocesos encargados de recibir request y permission y recibir sus análogos
        filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        num_msg = length(filtered_list)
        Common.enviar(filtered_list, rr_pid, proc_id)
        rr_list = Common.recibir(num_msg, [])

        filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        num_msg = length(filtered_list)
        Common.enviar(filtered_list, rp_pid, proc_id)
        rp_list = Common.recibir(num_msg,[])
        send(rr_pid, {:update, rp_list})
        
        IO.puts("RECIBIDOS Y ENVIADOS PID")
        # Dar aleatoriedad
        Process.sleep(round(:rand.uniform(100)/100 * 2000))
        # Comenzar
        protocol(clock, proc_id, rr_pid, rr_list, rp_pid, rp_list)
    end

    ########################################################################################################
    #                                                                                                      #
    #                                       SECCIÓN PRINCIPAL                                              #
    #                                                                                                      #
    ########################################################################################################

    ########################################################################################################
    #                                       FUNCIÓN PRINCIPAL                                              #
    ########################################################################################################
    def protocol(clock, proc_id, rr_pid, rr_list, rp_pid, rp_list) do
        IO.puts("INICIO DEL PROTOCOLO")
        cs_state = :trying
        lrd = clock + 1
        op_type = Common.generar_operacion_escritor

        # Actualizar datos en subproceso encargado de recibir request
        send(rr_pid, {:update, cs_state, lrd, op_type})
        # Enviar peticiones de acceso al resto
        Common.enviar_request(lrd, proc_id, op_type, rr_list)
        # Recibir luz verde del subproceso encargado de recibir permission
        receive do
            {:ok} -> cs_state = :in
                     send(rr_pid, {:update, cs_state})
        end
        
        IO.puts("SECCION CRITICA")
        # Pedir al repositorio los datos y mostrarlos por pantalla
        repositorio = hd(Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "repositorio" end))
        description = Randomizer.randomizer(20, :alpha)
        send({:pprincipal, repositorio}, {op_type, self, description})
        op_type_s = Atom.to_string(op_type)
        receive do
            {:reply, :ok} -> IO.puts(op_type_s)
                             IO.puts(description)
        end
        
        cs_state = :out
        # Actualizar datos en subproceso encargado de recibir request
        send(rr_pid, {:update, cs_state})
        # Enviar permission al resto de procesos bloqueados
        send(rr_pid, {:need_perm_delayed, self})
        receive do
            {:perm_delayed, perm_delayed} -> Common.enviar_permission(proc_id, rp_list, perm_delayed)
        end
        send(rr_pid, {:reset_perm_delayed})
        send(rr_pid, {:need_clock, self})
        clock_n = 0
        receive do
            {:clock, new_clock} -> clock_n = new_clock 
        end
        
        IO.puts("FUERA SECCION CRITICA")
        # Dar aleatoriedad
        Process.sleep(round(:rand.uniform(100)/100 * 2000))
        protocol(clock_n, proc_id, rr_pid, rr_list, rp_pid, rp_list)
    end
end
