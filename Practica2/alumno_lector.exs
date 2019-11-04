# AUTORES: Eduardo Gimeno y Sergio Alvarez
# NIAs: 721615 y 740241
# FICHERO: alumno_lector.exs
# FECHA: 2 de noviembre de 2019
# TIEMPO: 
# DESCRIPCION: Código del lector
defmodule Lector do
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
    def begin_begin_op(proc_id, total_sistema) do
        # Inicializar variables que deben conocer desde un inicio los subprocesos encargados de recibir request y permission
        clock = 0
        lrd = clock
        cs_state = :out

        waiting_from = Enum.to_list 1..total_sistema
        waiting_from = List.delete(waiting_from, proc_id)

        # Crear subprocesos encargados de recibir request y permission
        rr_pid = spawn(Lector, :request, [proc_id, lrd, clock, cs_state])
        rp_pid = spawn(Lector, :permission, [waiting_from, waiting_from])

        # Enviar al resto de procesos princiaples los pids de los subprocesos encargados de recibir request y permission y recibir sus análogos
        filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        num_msg = length(filtered_list)
        enviar(filtered_list, rr_pid, proc_id)
        # No se consigue obtener la lista
        rr_list = Enum.reverse(recibir(num_msg, []))

        filtered_list = Enum.filter(Node.list, fn(x) -> Atom.to_string(x) =~ "alumno" || Atom.to_string(x) =~ "profesor" end)
        enviar(filtered_list, rp_pid, proc_id)
        # No se consigue obtener la lista
        rp_list = Enum.reverse(recibir(num_msg,[]))

        # Comenzar pre-protocol
        begin_op(clock, lrd, proc_id, rr_pid, rr_list, rp_pid, rp_list, cs_state)
    end

    def begin_op(clock, lrd, proc_id, rr_pid, rr_list, rp_pid, rp_list, cs_state) do
        # TODO
    end

    def request(proc_id, lrd, clock, cs_state) do
        # TODO
    end  

    def permission(waiting_from, waiting_from_permanent) do
        # TODO
    end
end