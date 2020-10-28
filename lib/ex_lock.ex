defmodule ExLock do
  defmodule Error do
    defexception message: ""
    @type t :: %ExLock.Error{}
  end

  defmodule Holder do
    defstruct connection: nil, release_task: nil

    @type t :: %ExLock.Holder{}
  end

  @spec acquire(key :: String.t(), opts :: Keyword.t()) :: {:ok, ExLock.Holder.t()} | {:error, ExLock.Error.t()}
  def acquire(key, opts \\ []) do
    lock_holder = Enum.reduce_while 1..attempt_count(opts), nil, fn attempt_number, _lock_holder ->
      connection = connection(ecto_repo(opts), lock_timeout(opts))
      key_integer = string_to_integer(key)
      result = Postgrex.query!(connection, "SELECT pg_try_advisory_lock(#{key_integer})", [])
      cond do
        Enum.at(Enum.at(result.rows, 0), 0) == true -> 
          {:ok, release_task} = Task.start fn ->
            :timer.sleep(lock_timeout(opts) - 100)
            ExLock.release(%ExLock.Holder{connection: connection, release_task: nil}, key)
          end
          {:halt, %ExLock.Holder{connection: connection, release_task: release_task}}
        attempt_number == attempt_count(opts) -> 
          release(%ExLock.Holder{connection: connection, release_task: nil}, key_integer)
          {:halt, nil}
        true ->
          release(%ExLock.Holder{connection: connection, release_task: nil}, key_integer)
          :timer.sleep(attempt_interval(opts))
          {:cont, nil}
      end
    end

    if is_nil(lock_holder), do: {:error, %ExLock.Error{message: "lock could not be acquired"}}, else: {:ok, lock_holder}
  end

  @spec acquire!(key :: String.t(), opts :: Keyword.t()) :: ExLock.Holder.t()
  def acquire!(key, opts \\ []) do
    case acquire(key, opts) do
      {:ok, connection} -> connection
      {:error, err} -> raise err
    end
  end

  @spec release(lock_holder :: ExLock.Holder.t(), key :: String.t()) :: nil
  def release(lock_holder, key) do
    try do
      Postgrex.query(lock_holder.connection, "SELECT pg_advisory_unlock(#{string_to_integer(key)})", [])
    catch _kind, _reason -> nil
    end

    try do
      DBConnection.Holder.checkin(lock_holder.connection.pool_ref)
    catch _kind, _reason -> nil
    end

    try do
      Process.exit(lock_holder.release_task, :ok)
    catch _kind, _reason -> nil
    end

    nil
  end

  @spec execute(key :: String.t(), function :: any(), opts :: Keyword.t()) :: {:ok, any()} | {:error, ExLock.Error.t()}
  def execute(key, opts, function) do
    acquire_opts = [repo: opts[:repo], lock_timeout: function_timeout(opts) + 5000, attempt_count: opts[:attempt_count], attempt_interval: opts[:attempt_interval]]
    case acquire(key, acquire_opts) do
      {:ok, lock_holder} -> execute_function(key, opts, function, lock_holder)
      {:error, err} -> {:error, err}
    end
  end

  defp execute_function(key, opts, function, lock_holder) do
    task = Task.async fn -> 
      try do
        {:ok, function.()}
      catch kind, reason -> {kind, reason}
      end
    end

    task_yield = Task.yield(task, function_timeout(opts))
    release(lock_holder, key)

    case task_yield do
      nil -> 
        Task.shutdown(task, :brutal_kill)
        {:error, %ExLock.Error{message: "function timed out"}}
      {:ok, task_result} -> 
        case task_result do
          {:ok, function_result} -> {:ok, function_result}
          {:error, reason} -> raise reason
          {:exit, reason} -> exit reason
          {:throw, reason} -> throw reason
        end
      {:exit, reason} -> exit(reason)
    end
  end

  @spec execute!(key :: String.t(), function :: any(), opts :: Keyword.t()) :: any()
  def execute!(key, function, opts \\ []) do
    case execute(key, function, opts) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  # generate a unique integer from the string for postgres
  defp string_to_integer(key) do
    :erlang.phash2(key)
  end

  # get connection
  defp connection(repo, timeout) do
    case (Ecto.Adapter.lookup_meta(repo).pid |> DBConnection.Holder.checkout(timeout: timeout)) do
      {:error, reason} -> raise reason
      {:ok, pool_ref, _conn_mod, _checkin, _conn_state} -> %DBConnection{pool_ref: pool_ref, conn_ref: make_ref()}
    end
  end

  # get ecto repo
  defp ecto_repo(opts) do
    (opts[:repo] || Application.get_env(:ex_lock, :repo))
  end

  # get lock timeout
  defp lock_timeout(opts) do
    (opts[:lock_timeout] || 15000)
  end

  # get function timeout
  defp function_timeout(opts) do
    (opts[:function_timeout] || 15000)
  end

  # get attempt count
  defp attempt_count(opts) do
    (opts[:attempt_count] || 1)
  end

  # get attempt count
  defp attempt_interval(opts) do
    (opts[:attempt_interval] || 1000)
  end
end
