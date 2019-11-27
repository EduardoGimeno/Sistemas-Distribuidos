require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    defstruct num_vista: 0, primario: :undefined, copia: :undefined

    # Constantes
    @latidos_fallidos 4

    @intervalo_latidos 50


    @doc """
        Acceso externo para constante de latidos fallios
    """
    def latidos_fallidos() do
        @latidos_fallidos
    end

    @doc """
        acceso externo para constante intervalo latido
    """
   def intervalo_latidos() do
       @intervalo_latidos
   end

   @doc """
        Generar un estructura de datos vista inicial
    """
    def vista_inicial() do
        %{num_vista: 0, primario: :undefined, copia: :undefined}
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
    @spec startService(node) :: boolean
    def startService(nodoElixir) do
        NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)
        
        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
   end

    #------------------- FUNCIONES PRIVADAS ----------------------------------

    # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
    def init_sv() do
        Process.register(self(), :servidor_gv)

        spawn(__MODULE__, :init_monitor, [self()]) # otro proceso concurrente

        #### VUESTRO CODIGO DE INICIALIZACION

        bucle_recepcion(vista_inicial(), vista_inicial(), [], true)
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end

    @doc """
        vista_valida: vista que se provee a los clientes del servicio de almacenamiento
        vista_tentativa: vista que se provee a los clientes del gestor de vistas
        latidos: registro de los fallos de cada nodo
                 [{Primario, Fallos}, {Copia, Fallos}, {Espera1, Fallos}, {Espera2, Fallos}]
        consistencia: estado de la consistencia en el sistema
                      false -> primario y copia caídos
                      true -> cualquier otro caso
    """
    defp bucle_recepcion(vista_valida, vista_tentativa, latidos, consistencia) do
        {vista_valida, vista_tentativa, latidos, consistencia} = receive do

                    {:latido, n_vista_latido, nodo_emisor} ->
                        # Primario y copia activos
                        if (consistencia == true) do
                            # Caída o se incorpora al sistema
                            if (n_vista_latido == 0) do
                                # Se incorpora un nuevo nodo con 0 fallos
                                latidos = latidos ++ [{nodo_emisor,0}]

                                # Comprobar si se añade a la vista tentativa como 
                                # primario o copia
                                # Nueva vista
                                cond do
                                    length(latidos) == 1 ->
                                        vista_tentativa = %{vista_tentativa | 
                                                num_vista: vista_tentativa.num_vista + 1}
                                        vista_tentativa = %{vista_tentativa |
                                                primario: nodo_emisor}
                                    length(latidos) == 2 ->
                                        vista_tentativa = %{vista_tentativa | 
                                                num_vista: vista_tentativa.num_vista + 1}
                                        vista_tentativa = %{vista_tentativa |
                                                copia: nodo_emisor}
                                end
                            # El nodo emisor tiene una vista
                            else
                                # Reiniciar latido para el nodo que lo ha enviado
                                latidos = for i <- latidos do
                                    if (elem(i, 0) == nodo_emisor) do
                                        {elem(i, 0), 0}
                                    else
                                        i
                                    end
                                end

                                # Si nodo emisor es el primario, la vista tentativa es la
                                # vista válida
                                if (n_vista_latido == vista_tentativa.num_vista and 
                                    nodo_emisor == vista_tentativa.primario) do
                                    vista_valida = vista_tentativa
                                end
                            end
                        end

                        # Enviar al nodo emisor la vista tentativa
                        send({:servidor_sa, nodo_emisor}, {:vista_tentativa,
                              vista_tentativa, vista_tentativa == vista_valida})

                        # Nuevo estado
                        {vista_valida, vista_tentativa, latidos, consistencia}

                    {:obten_vista_valida, pid} ->

                        # Enviar la vista válida
                        send(pid, {:vista_valida, vista_valida,
                                   vista_tentativa == vista_valida})

                        # Nuevo estado
                        {vista_valida, vista_tentativa, latidos, consistencia}                

                    :procesa_situacion_servidores ->
                
                        if (length(latidos) > 0) do
                            # Actualizar latidos
                            latidos = for i <- latidos, do: {elem(i, 0), elem(i, 1) + 1}

                            # Comprobar si el primario o la copia han caído
                            primario_caido = estado(vista_valida.primario, latidos)
                            copia_caida = estado(vista_valida.copia, latidos)

                            # Descartar nodos caídos
                            latidos = eliminar_caidos(latidos)

                            # Fallo, primario y copia han caído, se pierde la consistencia
                            if (primario_caido == true and copia_caida == true) do
                                vista_valida = vista_inicial()
                                consistencia = false
                                IO.puts("FALLO: Primario y copia han caido")
                            else
                                # Primario ha caído, promocionar copia a primario en la
                                # vista tentativa

                            end
                        end

        end

        bucle_recepcion(??????????)
    end
    
    # OTRAS FUNCIONES PRIVADAS VUESTRAS

end
