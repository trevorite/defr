defmodule MagicWand.NestedStateTest do
  use ExUnit.Case, async: true
  use MagicWand
  alias Algae.State
  alias Algae.Either.Right

  defmodule Repo do
    def get(_schema, _id) do
      raise "Shouldn't be called"
    end
  end

  defmodule User do
    use MagicWand

    defstruct [:id, :name]

    defr get_by_id(user_id) do
      Repo.get(__MODULE__, user_id) |> Right.new()
    end
  end

  defmodule Accounts do
    use MagicWand

    defr get_user_by_id(user_id) do
      monad %Right{} do
        user <- User.get_by_id(user_id)
        user |> Right.new()
      end
    end
  end

  defmodule UserController do
    use MagicWand

    defr profile(user_id_str) do
      user_id = String.to_integer(user_id_str)
      Accounts.get_user_by_id(user_id)
    end
  end

  test "inject 3rd layer" do
    assert [{:profile, 1}] == UserController.__magic_funs__()

    assert {%Right{right: %User{id: 1, name: "josevalim"}}, []} ==
             UserController.profile("1")
             |> MagicWand.run(%{&Repo.get/2 => fn _, _ -> %User{id: 1, name: "josevalim"} end})
  end

  test "inject 2nd layer" do
    assert [{:get_user_by_id, 1}] == Accounts.__magic_funs__()

    assert {%Right{right: %User{id: 2, name: "chrismccord"}}, []} ==
             UserController.profile("2")
             |> MagicWand.run(%{
               &User.get_by_id/1 => fn _ ->
                 State.new(fn state -> {Right.new(%User{id: 2, name: "chrismccord"}), state} end)
               end
             })

    # with `mock` macro
    assert {%Right{right: %User{id: 2, name: "chrismccord"}}, []} ==
             UserController.profile("2")
             |> MagicWand.run(
               mock(%{
                 &User.get_by_id/1 => Right.new(%User{id: 2, name: "chrismccord"})
               })
             )
  end
end
