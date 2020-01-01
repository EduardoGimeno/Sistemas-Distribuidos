Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
    
    # estado del servidor            
    defstruct num_vista: 0
              primario: :undefined
              copia: :undefined
              valida: false
              datos: %{}


    @intervalo_latido 50


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

        estado = %{num_vista: 0, primario: :undefined, copia: :undefined
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
            {op, param, nodo_origen}  ->

        end

        bucle_recepcion_principal(estado, nodo_servidor_gv)
    end
    
    #--------- Otras funciones privadas que necesiteis .......
end
