# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: common.exs
# FECHA: 5 de noviembre de 2019
# TIEMPO: 15 min
# DESCRIPCION: Código común para lectores y escritores
defmodule Common do
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

    ########################################################################################################
    #                                                                                                      #
    #                                       SECCIÓN PRINCIPAL                                              #
    #                                                                                                      #
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

    # Enviar permission a los subprocesos que las reciben
    def enviar_permission(proc_id, rp_list, perm_delayed) do
        if (length(perm_delayed) != 0) do
            send_p = List.first(perm_delayed)
            rppid = obtener_rppid(send_p, rp_list)
            IO.puts "ENVIAR PERMISSION: #{inspect send_p}"
            send(rppid, {:ack, proc_id})
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
                                                                IO.inspect("PROCESO A LA ESPERA: #{proc_id_r}")
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
            send(main_pid, {:ok})
            permission(waiting_from_permanent, waiting_from_permanent, main_pid)
        else     
            receive do
                {:ack, proc_id} -> permission(List.delete(waiting_from, proc_id), waiting_from_permanent, main_pid)
            end
        end    
    end
end