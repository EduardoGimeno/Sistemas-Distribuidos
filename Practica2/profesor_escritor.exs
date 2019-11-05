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

    # Enviar al resto de procesos principales el pid indicado
    def enviar(list, pid, proc_id) do
        if length(list) != 0 do
            node_env = List.first(list)
            send({:pprincipal, node_env}, {:pid, pid, proc_id})
            list = List.delete_at(list, 0)
            enviar(list, pid, proc_id)
        end 
    end

    # Recibir del resto de procesos principales un pid
    def recibir(num_msg, list) do
        if num_msg != 0 do
            receive do
                {:pid, pid, proc_id} -> nlist = list ++ [[proc_id, pid]]
                                        recibir(num_msg-1, nlist)
            end
        else
            list
        end
    end
            
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
        rr_pid = spawn(Escritor, :request, [proc_id, lrd, clock, cs_state, [], :nil, [], true])
        rp_pid = spawn(Escritor, :permission, [waiting_from, waiting_from, self])

        # Enviar al resto de procesos princiaples los pids de los subprocesos encargados de recibir request y permission y recibir sus análogos
        filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        num_msg = length(filtered_list)
        enviar(filtered_list, rr_pid, proc_id)
        rr_list = recibir(num_msg, [])

        filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        num_msg = length(filtered_list)
        enviar(filtered_list, rp_pid, proc_id)
        rp_list = recibir(num_msg,[])
        send(rr_pid, {:update, rp_list})
        
        IO.puts("RECIBIDOS Y ENVIADOS PID")
        # Dar aleatoriedad
        Process.sleep(round(:rand.uniform(100)/100 * 2000))
        # Comenzar
        protocol(clock, lrd, proc_id, rr_pid, rr_list, rp_pid, rp_list, cs_state)
    end

    ########################################################################################################
    #                                                                                                      #
    #                                       SECCIÓN PRINCIPAL                                              #
    #                                                                                                      #
    ########################################################################################################

    ########################################################################################################
    #                                       FUNCIONES AUXILIARES                                           #
    ########################################################################################################

    # Enviar request a los subprocesos que las reciben
    def enviar_request(lrd, proc_id, op_type, rr_list) do
        if length(rr_list) != 0 do
            proc_env = List.first(rr_list)
            rrpid_env = hd(List.delete_at(proc_env, 0))
            send(rrpid_env, {:request, lrd, proc_id, op_type})
            rr_list = List.delete_at(rr_list, 0)
            enviar_request(lrd, proc_id, op_type, rr_list)  
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

    # Enviar permission a los subprocesos que las reciben
    def enviar_permission(proc_id, rp_list, perm_delayed) do
        if (length(perm_delayed) != 0) do
            send_p = List.first(perm_delayed)
            rppid = obtener_rppid(send_p, rp_list)
            enviar_permission(proc_id, rp_list, List.delete_at(perm_delayed, 0))
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

    # Obtener el pid del subproceso encargado de recibir permission del proceso principal indicado
    def obtener_rppid(proc_id_r, rp_list) do
        sublist = List.first(rp_list)
        if (List.first(sublist) == proc_id_r) do
            nsublist = List.delete_at(sublist, 0)
            hd(nsublist)
        else
            obtener_rppid(proc_id_r, List.delete_at(rp_list, 0))
        end
    end

    ########################################################################################################
    #                                       FUNCIÓN PRINCIPAL                                              #
    ########################################################################################################
    def protocol(clock, lrd, proc_id, rr_pid, rr_list, rp_pid, rp_list, cs_state) do
        IO.puts("INICIO DEL PROTOCOLO")
        cs_state = :trying
        lrd = clock + 1
        op_type = generar_operacion_escritor

        # Actualizar datos en subproceso encargado de recibir request
        send(rr_pid, {:update, cs_state, lrd, op_type})
        # Enviar peticiones de acceso al resto
        enviar_request(lrd, proc_id, op_type, rr_list)
        # Recibir luz verde del subproceso encargado de recibir permission
        receive do
            {:ok} -> cs_state = :in
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
            {:perm_delayed, perm_delayed} -> enviar_permission(proc_id, rp_list, perm_delayed)
        end
        send(rr_pid, {:reset_perm_delayed})
        send(rr_pid, {:need_clock, self})
        receive do
            {:clock, new_clock} -> clock = new_clock 
        end
        
        IO.puts("FUERA SECCION CRITICA")
        # Dar aleatoriedad
        Process.sleep(round(:rand.uniform(100)/100 * 2000))
        protocol(clock, lrd, proc_id, rr_pid, rr_list, rp_pid, rp_list, cs_state)
    end

    ########################################################################################################
    #                                    FUNCIÓN SUBPROCESO REQUEST                                        #
    ########################################################################################################
    def request(proc_id, lrd, clock, cs_state, perm_delayed, op_type, rp_list, first_it) do
        if (first_it == true) do
            receive do
                {:update, rp_list_u} -> rp_list_n = rp_list_u
                                        request(proc_id, lrd, clock, cs_state, perm_delayed, op_type, rp_list_n, false)
            end
        else
            receive do
                {:update, cs_state_u, lrd_u, op_type_u} -> cs_state_n = cs_state_u
                                                           lrd_n = lrd_u
                                                           op_type_n = op_type_u
                                                           request(proc_id, lrd_n, clock, cs_state_n, perm_delayed, op_type_n, rp_list, false)
                {:update, cs_state_u} -> cs_state_n = cs_state_u
                                         request(proc_id, lrd, clock, cs_state_n, perm_delayed, op_type, rp_list, false)
                {:need_perm_delayed, pp_pid} -> send(pp_pid, {:perm_delayed, perm_delayed})
                                                request(proc_id, lrd, clock, cs_state, perm_delayed, op_type, rp_list, false)
                {:reset_perm_delayed} -> request(proc_id, lrd, clock, cs_state, [], op_type, rp_list, false)
                {:need_clock, pp_pid} -> send(pp_pid, {:clock, clock})
                                         request(proc_id, lrd, clock, cs_state, perm_delayed, op_type, rp_list, false)
                {:request, lrd_r, proc_id_r, op_type_r} -> clock_n = max(clock,lrd_r)
                                                           prio = (cs_state != :out) and comprobar_orden_total(proc_id,lrd,proc_id_r,lrd_r) and exclude(op_type,op_type_r)
                                                           if prio == true do
                                                                n_perm_delayed = perm_delayed ++ [proc_id_r]
                                                                request(proc_id, lrd, clock_n, cs_state, n_perm_delayed, op_type, rp_list, false)
                                                           else
                                                                proc_env = obtener_rppid(proc_id_r, rp_list)
                                                                send(proc_env, {:ack, proc_id})
                                                                request(proc_id, lrd, clock_n, cs_state, perm_delayed, op_type, rp_list, false)
                                                           end
            end
        end
    end

    ########################################################################################################
    #                                    FUNCIÓN SUBPROCESO PERMISSION                                     #
    ########################################################################################################
    def permission(waiting_from, waiting_from_permanent, main_pid) do
        if (length(waiting_from) == 0) do
            send(main_pid,{:ok})
            permission(waiting_from_permanent, waiting_from_permanent, main_pid)
        else     
            receive do
                {:ack, proc_id} -> permission(List.delete(waiting_from, proc_id), waiting_from_permanent, main_pid)
            end
        end    
    end
end
