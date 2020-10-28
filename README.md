# ExLock

Postgres advisory lock backed elixir Library for locking critical section of code running on multiple machines.

## Installation

It can be installed by adding `ex_lock` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_lock, "~> 0.1.1"}
  ]
end
```

## Usage
```elixir
ExLock.execute "lock_key", [], fn ->
  # critical section
end
```

**Parameters** 
- key (mandatory) - String on which lock is getting acquired. 
- options (mandatory - [] can be passed)  - Keyword list. Supported keys are function_timeout, attempt_count, attempt_interval
    - function_timeout (default - 15000)  - Time in millisecond after which the function provided will time out. This is to make sure that a process does not acquire the lock for indefinite time.
    - attempt_count (default - 1)  - Number of times the code will try to acquire the lock. This package does not wait on trying to acquire the lock. Instead, attempt_count needs to be specified.
    - attempt_interval (default - 1000)  - Time between the attempts. 
- function - Critical section of code 

**Responses**

```elixir
{:ok, function_result} - In case lock has been acquired and function has executed properly. 
{:error, %ExLock.Error{message: "lock could not be acquired"}} - In case lock has not been acquired
{:error, %ExLock.Error{message: "function timed out"}} - In case function has timed out.
```

Bang function for execute is also supported.
```elixir
ExLock.execute! "lock_key", [], fn ->
  # critical section
end
```

Lock can also be acquired and released from the code. 

```elixir
{:ok, lock_holder} = ExLock.acquire("lock_key", [])

# critical section

ExLock.release(lock_holder, "lock_key")
```

If lock is getting acquired in this fashion, please make sure it gets released after the work is done.

Second parameter is a keyword list supporting following values.
- lock_timeout (default - 15000)  - Time in millisecond after which the lock automatically gets released. This is to make sure that a process does not acquire the lock for indefinite time.
- attempt_count (default - 1)  - Number of times the code will try to acquire the lock. This package does not wait on trying to acquire the lock. Instead, attempt_count needs to be specified.
- attempt_interval (default - 1000)  - Time between the attempts. 

Bang function for acquire is also supported.
```elixir
lock_holder = ExLock.acquire!("lock_key", [])

# critical section

ExLock.release(lock_holder, "lock_key")
```

Check the specs here - [ExLock Spec](https://hexdocs.pm/ex_lock/ExLock.html)