# AUTOR: Eduardo Gimeno y Sergio Álvarez
# NIAs: 721615 y 740241
# FICHERO: servidor_sa.exs
# FECHA: 11 de enero de 2020
# TIEMPO: 8 h
# DESCRIPCIÓN: Servidor de almacenamiento

Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
    
    # estado del servidor            
    defstruct num_vista: 0,
              primario: :undefined,
              copia: :undefined,
              valida: false,
              datos: %{}


    @intervalo_latido 50

    #@tiempo_espera_respuesta 30


    @doc """
        Obtener el hash de un string Elixir
            - Necesario pasar, previamente,  a formato string Erlang
         - Devuelve entero
    """
    def hash(string_concatenado) do
        String.to_charlist(string_concatenado) |> :erlang.phash2
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file)
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node, node) :: pid
    def startService(nodoSA, nodo_servidor_gv) do
        NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)
        
        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
   end

    #------------------- Funciones privadas -----------------------------

    def init_sa(nodo_servidor_gv) do
        Process.register(self(), :servidor_sa)
        # Process.register(self(), :cliente_gv)
 

    #------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........

        spawn(__MODULE__, :generar_latido, [self()])

        estado = %{num_vista: 0, primario: :undefined, copia: :undefined,
                   valida: false, datos: %{}}

         # Poner estado inicial
        bucle_recepcion_principal(estado, nodo_servidor_gv) 
    end

    @doc """
        Generar un latido cada @intervalo_latido ms, funciona como
        una alarma
    """
    def generar_latido(pid) do
        send(pid, {:enviar_latido})
        Process.sleep(@intervalo_latido)
        generar_latido(pid)
    end

    defp bucle_recepcion_principal(estado, nodo_servidor_gv) do
        {estado, nodo_servidor_gv} = receive do
            # Solicitudes de lectura y escritura
            # de clientes del servicio alm.
            {:lee, clave, pid} -> 
                if (estado.valida == true && estado.primario == Node.self()) do
                    # Primario con vista válida
                    valor = Map.get(estado.datos, String.to_atom(clave))
                    # Comprobar si es nulo
                    valor = if (valor == nil) do
                                ""
                            else
                                valor
                            end
                    # Enviar resultado al cliente
                    send({:cliente_sa, pid}, {:resultado, valor})
                else
                    # No primario o vista no válida
                    send({:cliente_sa, pid}, {:resultado, :no_soy_primario_valido})
                end

                # Devolver estado
                {estado, nodo_servidor_gv}

            {:escribe_generico, {clave, nuevo_valor, con_hash}, pid} ->
                {estado} = if (estado.valida == true && 
                               estado.primario == Node.self()) do
                    # Primario con vista válida
                    # Enviar a la copia para que lo escriba
                    send({:servidor_sa, estado.copia}, {:escribe_generico, 
                          {clave, nuevo_valor, con_hash}, Node.self()})
                    # Escribir nuevo valor en la base de datos
                    {estado} = receive do
                        {:ok, valor} -> {_valor, estado} = escribir_dato(estado, clave, valor, 
                                                                         con_hash)
                                        # Enviar al cliente la confirmación
                                        send({:cliente_sa, pid}, {:resultado, valor})
                                        {estado}
                    #after @tiempo_espera_respuesta ->
                    #    send({:cliente_sa, pid}, {:resultado, :no_soy_primario_valido})
                    #    {estado}
                    #end

                    {estado}
                else
                    {estado} = if (estado.valida == true && estado.copia == Node.self()
                                   && estado.primario == pid) do
                        # Copia con vista válida
                        {valor, estado} = escribir_dato(estado, clave, nuevo_valor, 
                                                        con_hash)
                        # Enviar confirmación primario
                        send({:servidor_sa, pid}, {:ok, valor})
        
                        {estado}
                    else
                        # No primario, ni copia o vista no válida
                        send({:cliente_sa, pid}, {:resultado, :no_soy_primario_valido})

                        {estado}
                    end

                    {estado}
                end

                # Devolver estado
                {estado, nodo_servidor_gv}

            {:enviar_latido} ->
                {vista, valida} = ClienteGV.latido(nodo_servidor_gv, estado.num_vista)
                estadoAnterior = estado
                estado = %{estado | num_vista: vista.num_vista,
                                    primario: vista.primario,
                                    copia: vista.copia,
                                    valida: valida}

                # Primer primario
                if (estado.primario == Node.self() && estado.num_vista == 1) do
                    ClienteGV.latido(nodo_servidor_gv, -1)
                else
                    # Primario y copia nueva
                    if (estado.primario == Node.self() && 
                        estado.copia != estadoAnterior.copia) do
                        send({:servidor_sa, estado.copia}, 
                             {:copiar_datos, estado.datos})
                    end
                    ClienteGV.latido(nodo_servidor_gv, estado.num_vista)
                end

                # Devolver estado
                {estado, nodo_servidor_gv}

            {:copiar_datos, datos} ->
                # Copiar datos
                estado = if (estado.copia == Node.self()) do
                    %{estado | datos: datos}
                else
                    estado
                end

                # Devolver estado
                {estado, nodo_servidor_gv}
        end

        bucle_recepcion_principal(estado, nodo_servidor_gv)
    end
    
    #--------- Otras funciones privadas que necesiteis .......
    defp escribir_dato(estado, clave, valor, hash) do
        valor = if (hash == true) do
            valorAnterior = Map.get(estado.datos, String.to_atom(clave))
            hash(valorAnterior <> valor)
        else
            valor
        end

        valor = if (valor == nil) do
            ""
        else
            valor
        end
        
        estado = %{estado | datos: Map.put(estado.datos, 
                                           String.to_atom(clave), valor)}
        {valor, estado}
    end

end
