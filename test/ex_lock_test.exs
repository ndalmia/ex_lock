defmodule ExLockTest do
  use ExUnit.Case
  doctest ExLock

  defmodule Repo do
    use Ecto.Repo, otp_app: :ex_lock, adapter: Ecto.Adapters.Postgres
  end

  setup_all do
    Application.put_env(:ex_lock, ExLockTest.Repo, [database: "ex_lock_test"])
    Application.put_env(:ex_lock, :repo, ExLockTest.Repo)
    ExLockTest.Repo.start_link()
    :ok
  end

  test "acquire success in first attempt" do
    acquire1 = ExLock.acquire("lock_key")

    acquire2 = ExLock.acquire("lock_key")

    ExLock.release(elem(acquire1, 1), "lock_key")

    assert (elem(acquire1, 0) == :ok && !is_nil(elem(acquire1, 1)) && acquire2 == {:error, %ExLock.Error{message: "lock could not be acquired"}})
  end

  test "acquire success after 3 attempts" do
    acquire1 = ExLock.acquire("lock_key", lock_timeout: 1900)

    acquire2 = ExLock.acquire("lock_key", attempt_count: 3)

    ExLock.release(elem(acquire2, 1), "lock_key")

    assert (elem(acquire1, 0) == :ok && elem(acquire2, 0) == :ok)
  end

  test "acquire failure after 3 attempts" do
    acquire1 = ExLock.acquire("lock_key")

    acquire2 = ExLock.acquire("lock_key", attempt_count: 3)

    ExLock.release(elem(acquire1, 1), "lock_key")

    assert (elem(acquire1, 0) == :ok && acquire2 == {:error, %ExLock.Error{message: "lock could not be acquired"}})
  end

  test "acquire lock_timeout after 3 seconds" do
    acquire1 = ExLock.acquire("lock_key", lock_timeout: 3000)

    :timer.sleep(3001)

    acquire2 = ExLock.acquire("lock_key")

    ExLock.release(elem(acquire2, 1), "lock_key")

    assert (elem(acquire1, 0) == :ok && elem(acquire2, 0) == :ok)
  end

  test "acquire! ok" do
    acquire1 = ExLock.acquire!("lock_key")

    ExLock.release(acquire1, "lock_key")

    assert (acquire1 != :ok)
  end

  test "acquire! error" do
    acquire1 = ExLock.acquire!("lock_key")

    assert_raise ExLock.Error, fn ->
      ExLock.acquire!("lock_key")
    end

    ExLock.release(acquire1, "lock_key")
  end

  test "release" do
    acquire1 = ExLock.acquire("lock_key")

    ExLock.release(elem(acquire1, 1), "lock_key")

    acquire2 = ExLock.acquire("lock_key")

    ExLock.release(elem(acquire2, 1), "lock_key")

    assert (elem(acquire1, 0) == :ok && elem(acquire2, 0) == :ok)
  end

  test "execute lock failure" do
    acquire1 = ExLock.acquire!("lock_key")

    execute = ExLock.execute "lock_key", [], fn ->
      2
    end

    ExLock.release(acquire1, "lock_key")

    assert execute == {:error, %ExLock.Error{message: "lock could not be acquired"}}
  end

  test "execute function giving result" do
    execute = ExLock.execute "lock_key", [], fn ->
      2
    end

    assert execute == {:ok, 2}
  end

  test "execute function raising error" do
    try do
      ExLock.execute "lock_key", [], fn ->
        raise "hello"
      end
    catch kind, _reason ->
      assert kind == :error
    end
  end

  test "execute function throwing error" do
    try do
      ExLock.execute "lock_key", [], fn ->
        throw "hello"
      end
    catch kind, _reason ->
      assert kind == :throw
    end
  end

  test "execute function exiting error" do
    try do
      ExLock.execute "lock_key", [], fn ->
        exit "hello"
      end
    catch kind, _reason ->
      assert kind == :exit
    end
  end

  test "execute function timing out" do
    execute = ExLock.execute "lock_key", [function_timeout: 3000], fn ->
      :timer.sleep(4000)
    end

    assert execute == {:error, %ExLock.Error{message: "function timed out"}}
  end

  test "execute! ok" do
    execute = ExLock.execute! "lock_key", [], fn ->
      2
    end

    assert execute == 2
  end

  test "execute! error" do
    assert_raise ExLock.Error, fn ->
      ExLock.execute! "lock_key", [function_timeout: 3000], fn ->
        :timer.sleep(4000)
      end
    end
  end
end
