# AUTOR: Eduardo Gimeno y Sergio Álvarez
# NIAs: 721615 y 740241
# FICHERO: servidor_gv.exs
# FECHA: diciembre de 2019
# TIEMPO: 13 h
# DESCRIPCIÓN: Servidor gestor de vistas

# Para utilizar IEx.pry
require IEx

defmodule ServidorGV do
  @moduledoc """
      modulo del servicio de vistas
  """

  # Tipo estructura de datos que guarda el estado del servidor de vistas
  # COMPLETAR  con lo campos necesarios para gestionar
  # el estado del gestor de vistas
  defstruct vista_valida: %{num_vista: 0, primario: :undefined, copia: :undefined},
            vista_tentativa: %{num_vista: 0, primario: :undefined, copia: :undefined},
            latidos: [],
            consistencia: true

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

  def estado_inicial() do
    %{
      vista_valida: vista_inicial(),
      vista_tentativa: vista_inicial(),
      latidos: [],
      consistencia: true
    }
  end

  @doc """
      Poner en marcha el servidor para gestión de vistas
      Devolver atomo que referencia al nuevo nodo Elixir
  """
  @spec startNodo(String.t(), String.t()) :: node
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

  # ------------------- FUNCIONES PRIVADAS ----------------------------------

  # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
  def init_sv() do
    Process.register(self(), :servidor_gv)

    # otro proceso concurrente
    spawn(__MODULE__, :init_monitor, [self()])

    #### VUESTRO CODIGO DE INICIALIZACION

    bucle_recepcion(estado_inicial())
  end

  def init_monitor(pid_principal) do
    send(pid_principal, :procesa_situacion_servidores)
    Process.sleep(@intervalo_latidos)
    init_monitor(pid_principal)
  end

  @doc """
      estado: estado actual del sistema
  """
  defp bucle_recepcion(estado) do
    nuevo_estado =
      receive do
        {:latido, n_vista_latido, nodo_emisor} ->
          gestionar_latido(estado, n_vista_latido, nodo_emisor)

        {:obten_vista_valida, pid} ->
          # Enviar la vista válida
          send(
            pid,
            {:vista_valida, estado.vista_valida, estado.vista_tentativa == estado.vista_valida}
          )

          estado

        :procesa_situacion_servidores ->
          gestionar_servidores(estado)
      end

    bucle_recepcion(nuevo_estado)
  end

  # OTRAS FUNCIONES PRIVADAS VUESTRAS

  @doc """
    Gestionar el latido recibido
  """
  defp gestionar_latido(estado, n_vista_latido, nodo_emisor) do
    nuevo_estado = estado
    # Primario y copia activos
    if nuevo_estado.consistencia == true do
      # Caída o se incorpora al sistema
      if n_vista_latido == 0 do
        # Comprobar si ha caído el primario o la copia y ha rearrancado rápidamente
        # Eliminar nodo de la lista de latidos si ha rearrancado rápidamente
        actualizar_latidos =
          if length(nuevo_estado.latidos) > 0 do
            eliminar_caido(nodo_emisor, nuevo_estado.latidos)
          else
            nuevo_estado.latidos
          end

        nuevo_estado = %{nuevo_estado | latidos: actualizar_latidos}

        # Promocionar copia a primario o nodo en espera a copia en caso
        # de que haya rearrancado rápidamente
        nuevo_estado =
          cond do
            nuevo_estado.vista_tentativa.primario == nodo_emisor ->
              actualizar_vista_tentativa = nuevo_estado.vista_tentativa

              actualizar_vista_tentativa = %{
                actualizar_vista_tentativa
                | num_vista: actualizar_vista_tentativa.num_vista + 1
              }

              actualizar_vista_tentativa = %{
                actualizar_vista_tentativa
                | primario: actualizar_vista_tentativa.copia
              }

              nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}

            nuevo_estado.vista_tentativa.copia == nodo_emisor ->
              nuevo_estado =
                if length(nuevo_estado.latidos) > 1 do
                  actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                  actualizar_vista_tentativa = %{
                    actualizar_vista_tentativa
                    | copia: elem(Enum.at(nuevo_estado.latidos, 1), 0)
                  }

                  nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                  nuevo_estado
                else
                  actualizar_vista_tentativa = nuevo_estado.vista_tentativa
                  actualizar_vista_tentativa = %{actualizar_vista_tentativa | copia: :undefined}
                  nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                  IO.puts("AVISO: Copia indefinida")
                  nuevo_estado
                end

            true ->
              nuevo_estado
          end

        # Se incorpora un nuevo nodo con 0 fallos
        actualizar_latidos = nuevo_estado.latidos ++ [{nodo_emisor, 0}]
        nuevo_estado = %{nuevo_estado | latidos: actualizar_latidos}

        # Comprobar si se añade a la vista tentativa como 
        # primario o copia
        # Nueva vista
        actualizar_vista_tentativa = nuevo_estado.vista_tentativa

        actualizar_vista_tentativa =
          cond do
            length(nuevo_estado.latidos) == 1 ->
              vista_tentativa_nueva = %{
                actualizar_vista_tentativa
                | num_vista: actualizar_vista_tentativa.num_vista + 1
              }

              _vista_tentativa_nueva = %{vista_tentativa_nueva | primario: nodo_emisor}

            length(nuevo_estado.latidos) == 2 ->
              vista_tentativa_nueva = %{
                actualizar_vista_tentativa
                | num_vista: actualizar_vista_tentativa.num_vista + 1
              }

              _vista_tentativa_nueva = %{vista_tentativa_nueva | copia: nodo_emisor}

            true ->
              actualizar_vista_tentativa
          end

        nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}

        # Enviar al nodo emisor la vista tentativa
        send(
          {:cliente_gv, nodo_emisor},
          {:vista_tentativa, nuevo_estado.vista_tentativa,
           nuevo_estado.vista_tentativa == nuevo_estado.vista_valida}
        )

        nuevo_estado

        # El nodo emisor tiene una vista
      else
        # Reiniciar latido para el nodo que lo ha enviado
        actualizar_latidos =
          for i <- nuevo_estado.latidos do
            if elem(i, 0) == nodo_emisor do
              {elem(i, 0), 0}
            else
              i
            end
          end

        nuevo_estado = %{nuevo_estado | latidos: actualizar_latidos}

        # Si nodo emisor es el primario, la vista tentativa es la
        # vista válida
        actualizar_vista_valida =
          if n_vista_latido == nuevo_estado.vista_tentativa.num_vista and
               nodo_emisor == nuevo_estado.vista_tentativa.primario do
            nuevo_estado.vista_tentativa
          else
            nuevo_estado.vista_valida
          end

        nuevo_estado = %{nuevo_estado | vista_valida: actualizar_vista_valida}

        # Enviar al nodo emisor la vista tentativa
        send(
          {:cliente_gv, nodo_emisor},
          {:vista_tentativa, nuevo_estado.vista_tentativa,
           nuevo_estado.vista_tentativa == nuevo_estado.vista_valida}
        )

        nuevo_estado
      end
    else
      # Enviar al nodo emisor la vista tentativa
      send(
        {:cliente_gv, nodo_emisor},
        {:vista_tentativa, nuevo_estado.vista_tentativa,
         nuevo_estado.vista_tentativa == nuevo_estado.vista_valida}
      )

      nuevo_estado
    end
  end

  @doc """
    Gestionar el estado de los servidores
  """
  defp gestionar_servidores(estado) do
    nuevo_estado = estado

    if length(nuevo_estado.latidos) > 0 do
      # Actualizar latidos
      actualizar_latidos = for i <- nuevo_estado.latidos, do: {elem(i, 0), elem(i, 1) + 1}
      nuevo_estado = %{nuevo_estado | latidos: actualizar_latidos}

      # Comprobar si el primario o la copia han caído
      primario_vivo = estado(nuevo_estado.vista_valida.primario, nuevo_estado.latidos)
      copia_viva = estado(nuevo_estado.vista_valida.copia, nuevo_estado.latidos)

      # Descartar nodos caídos
      actualizar_latidos = eliminar_caidos(nuevo_estado.latidos)
      nuevo_estado = %{nuevo_estado | latidos: actualizar_latidos}

      # Fallo, primario y copia han caído, se pierde la consistencia
      nuevo_estado =
        if primario_vivo == false and copia_viva == false do
          actualizar_consistencia = false
          nuevo_estado = %{nuevo_estado | consistencia: actualizar_consistencia}
          actualizar_vista_tentativa = nuevo_estado.vista_tentativa
          actualizar_vista_tentativa = %{
            actualizar_vista_tentativa
            | primario: :undefined
          }
          actualizar_vista_tentativa = %{
            actualizar_vista_tentativa
            | copia: :undefined
          }
          nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
          IO.puts("FALLO: Primario y copia han caido")
          nuevo_estado
        else
          nuevo_estado =
            if primario_vivo == false do
              # Si el primario ha caido sin confirmar la vista el sistema queda bloqueado
              nuevo_estado =
                if nuevo_estado.vista_tentativa.num_vista != nuevo_estado.vista_valida.num_vista do
                  actualizar_consistencia = false
                  nuevo_estado = %{nuevo_estado | consistencia: actualizar_consistencia}
                  actualizar_vista_tentativa = nuevo_estado.vista_tentativa
                  actualizar_vista_tentativa = %{
                    actualizar_vista_tentativa
                    | primario: :undefined
                  }
                  nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                  IO.puts("FALLO: Primario ha caído sin confirmar vista")
                  nuevo_estado
                else
                  # Primario ha caído, promocionar copia a primario en la
                  # vista tentativa (generar nueva vista)
                  actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                  actualizar_vista_tentativa = %{
                    actualizar_vista_tentativa
                    | num_vista: actualizar_vista_tentativa.num_vista + 1
                  }

                  actualizar_vista_tentativa = %{
                    actualizar_vista_tentativa
                    | primario: actualizar_vista_tentativa.copia
                  }

                  nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}

                  # Promocionar nodo en espera a copia si existe
                  nuevo_estado =
                    if length(nuevo_estado.latidos) > 1 do
                      actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                      actualizar_vista_tentativa = %{
                        actualizar_vista_tentativa
                        | copia: elem(Enum.at(nuevo_estado.latidos, 1), 0)
                      }

                      nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                      nuevo_estado
                    else
                      actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                      actualizar_vista_tentativa = %{
                        actualizar_vista_tentativa
                        | copia: :undefined
                      }

                      nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                      IO.puts("AVISO: Copia indefinida")
                      nuevo_estado
                    end

                  nuevo_estado
                end
            else
              nuevo_estado
            end

          nuevo_estado =
            if copia_viva == false do
              # Si el primario ha caido sin confirmar la vista el sistema queda bloqueado
              nuevo_estado =
                if nuevo_estado.vista_tentativa.num_vista != nuevo_estado.vista_valida.num_vista do
                  actualizar_consistencia = false
                  nuevo_estado = %{nuevo_estado | consistencia: actualizar_consistencia}
                  actualizar_vista_tentativa = nuevo_estado.vista_tentativa
                  actualizar_vista_tentativa = %{
                    actualizar_vista_tentativa
                    | primario: :undefined
                  }
                  nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                  IO.puts("FALLO: Primario ha caído sin confirmar vista")
                  nuevo_estado
                else
                  # Copia ha caído, promocionar nodo en espera a copia,
                  # si existe, en la vista tentativa (generar nueva vista)
                  actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                  actualizar_vista_tentativa = %{
                    actualizar_vista_tentativa
                    | num_vista: actualizar_vista_tentativa.num_vista + 1
                  }

                  nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}

                  nuevo_estado =
                    if length(nuevo_estado.latidos) > 1 do
                      actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                      actualizar_vista_tentativa = %{
                        actualizar_vista_tentativa
                        | copia: elem(Enum.at(nuevo_estado.latidos, 1), 0)
                      }

                      nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                      nuevo_estado
                    else
                      actualizar_vista_tentativa = nuevo_estado.vista_tentativa

                      actualizar_vista_tentativa = %{
                        actualizar_vista_tentativa
                        | copia: :undefined
                      }

                      nuevo_estado = %{nuevo_estado | vista_tentativa: actualizar_vista_tentativa}
                      IO.puts("AVISO: Copia indefinida")
                      nuevo_estado
                    end

                  nuevo_estado
                end
            else
              nuevo_estado
            end

          nuevo_estado
        end

      nuevo_estado
    else
      nuevo_estado
    end
  end

  @doc """
    Devuelve true si el nodo se encuentra activo o indefinido, false
    en cualquier otro caso
  """
  defp estado(nodo, [latido | latidos]) do
    # Nodo indefinido
    if nodo == :undefined do
      true
    else
      # No hay nodos en el sistema
      if length([latido | latidos]) == 0 do
        false
      else
        # Nodo del que se quiere saber el estado
        if elem(latido, 0) == nodo do
          # Nodo ha superado el número de latidos fallidos
          if elem(latido, 1) > latidos_fallidos() do
            false
          else
            true
          end

          # Seguir buscando
        else
          # Comprobar si quedan más elementos en la lista
          if length(latidos) > 0 do
            estado(nodo, latidos)
          else
            false
          end
        end
      end
    end
  end

  @doc """
    Eliminar nodos que hayan superado el número de latidos fallidos
  """
  defp eliminar_caidos([latido | latidos]) do
    if elem(latido, 1) <= latidos_fallidos() do
      # No ha superado, se mantiene
      if length(latidos) > 0 do
        [latido] ++ eliminar_caidos(latidos)
      else
        [latido]
      end
    else
      # Descartar nodo
      if length(latidos) > 0 do
        eliminar_caidos(latidos)
      else
        []
      end
    end
  end

  @doc """
    Eliminar de la lista de latidos el nodo indicado
  """
  defp eliminar_caido(nodo, [latido | latidos]) do
    if elem(latido, 0) == nodo do
      if length(latidos) > 0 do
        eliminar_caido(nodo, latidos)
      else
        []
      end
    else
      if length(latidos) > 0 do
        [latido] ++ eliminar_caido(nodo, latidos)
      else
        [latido]
      end
    end
  end
end
