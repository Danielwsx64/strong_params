defmodule StrongParams.FilterTest do
  use ExUnit.Case, async: true

  alias StrongParams.{Error, Filter}

  describe "apply/3" do
    test "filter and return required fields" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, required: [:name, :description])

      assert result == %{
               name: "Johnny Lawrence",
               description: "user description"
             }
    end

    test "filter and return permited fields" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, permited: [:name, :description])

      assert result == %{
               name: "Johnny Lawrence",
               description: "user description"
             }
    end

    test "dont return error when permited field is not found" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, permited: [:nickname, :name, :description])

      assert result == %{
               name: "Johnny Lawrence",
               description: "user description"
             }
    end

    test "handle nested attributes" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{"type" => "jpg"}
        }
      }

      filters = [required: [:name, address: [:street], attachments: [info: [:type]]]]

      result = Filter.apply(params, filters)

      assert result == %{
               name: "Johnny Lawrence",
               address: %{street: "First Avenue"},
               attachments: %{info: %{type: "jpg"}}
             }
    end

    test "filter and return required and permited" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{"type" => "jpg"}
        }
      }

      filters = [
        required: [:name, address: [:street]],
        permited: [attachments: [info: [:type, :size]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               address: %{street: "First Avenue"},
               attachments: %{info: %{type: "jpg"}},
               name: "Johnny Lawrence"
             }
    end

    test "merge required and permited" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => %{
          "info" => %{"type" => "jpg", "size" => "25M"}
        }
      }

      filters = [
        required: [:name, attachments: [info: [:type]]],
        permited: [attachments: [info: [:size]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               attachments: %{info: %{type: "jpg", size: "25M"}},
               name: "Johnny Lawrence"
             }
    end

    test "return error for required field" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        }
      }

      filters = [required: [:age, :nickname, address: [:street]]]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "required",
               errors: %{nickname: "is required", age: "is required"}
             }
    end

    test "nested errors" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{"type" => "jpg"}
        }
      }

      filters = [
        required: [:name, :nickname, address: [:city], attachments: [info: [:type, :size]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "required",
               errors: %{
                 attachments: %{info: %{size: "is required"}},
                 address: %{city: "is required"},
                 nickname: "is required"
               }
             }
    end

    test "dont return permited when required has errors" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{"type" => "jpg"}
        }
      }

      filters = [required: [attachments: [info: [:type, :size]]], permited: [:name]]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "required",
               errors: %{attachments: %{info: %{size: "is required"}}}
             }
    end
  end
end
