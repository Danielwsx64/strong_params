defmodule StrongParams.FilterTest do
  use ExUnit.Case, async: true

  alias StrongParams.Error
  alias StrongParams.Filter

  describe "apply/3" do
    test "filters and return required fields" do
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

    test "filters mixed key-type maps" do
      params = %{
        :name => "Johnny Lawrence",
        "description" => "user description"
      }

      result = Filter.apply(params, required: [:name, :description])

      assert result == %{
               name: "Johnny Lawrence",
               description: "user description"
             }
    end

    test "cast types" do
      params = %{
        "id" => "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
        "dates" => ["2021-11-29", "2021-10-30"]
      }

      result = Filter.apply(params, required: [{:id, Ecto.UUID}, {:dates, {:array, :date}}])

      assert result == %{
               id: "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
               dates: [~D[2021-11-29], ~D[2021-10-30]]
             }
    end

    test "success with the forbidden error opt as true" do
      params = %{
        "id" => "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
        "dates" => ["2021-11-29"]
      }

      result =
        Filter.apply(params,
          required: [{:id, Ecto.UUID}, {:dates, {:array, :date}}],
          forbidden_params_err: true
        )

      assert result == %{
               id: "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
               dates: [~D[2021-11-29]]
             }
    end

    test "casts errors" do
      params = %{
        "id" => "invalid",
        "date" => "invalid",
        "type" => "invalid"
      }

      result =
        Filter.apply(params,
          required: [
            {:id, Ecto.UUID},
            {:date, :date},
            {:type, Ecto.ParameterizedType.init(Ecto.Enum, values: [:type_a])}
          ]
        )

      assert result == %Error{
               errors: %{
                 type: "is invalid",
                 date: "is invalid",
                 id: "is invalid"
               },
               type: "invalid"
             }
    end

    test "casts on missing keys" do
      params = %{}

      result = Filter.apply(params, permitted: [{:date, :date}])

      assert result == %{}
    end

    test "filters and return permitted fields" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, permitted: [:name, :description])

      assert result == %{
               name: "Johnny Lawrence",
               description: "user description"
             }
    end

    test "does not return error when permitted field is not found" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, permitted: [:nickname, :name, :description])

      assert result == %{
               name: "Johnny Lawrence",
               description: "user description"
             }
    end

    test "handles nested attributes" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{
            "type" => "jpg",
            "id" => "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
            "date" => "2021-11-29"
          }
        }
      }

      filters = [
        required: [
          :name,
          address: [:street],
          attachments: [info: [{:id, Ecto.UUID}, {:date, :date}, :type]]
        ]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               name: "Johnny Lawrence",
               address: %{street: "First Avenue"},
               attachments: %{
                 info: %{
                   type: "jpg",
                   id: "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
                   date: ~D[2021-11-29]
                 }
               }
             }
    end

    test "filters and return required and permitted" do
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
        permitted: [attachments: [info: [:type, :size]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               address: %{street: "First Avenue"},
               attachments: %{info: %{type: "jpg"}},
               name: "Johnny Lawrence"
             }
    end

    test "merges required and permitted" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => %{
          "info" => %{"type" => "jpg", "size" => "25M"}
        }
      }

      filters = [
        required: [:name, attachments: [info: [:type]]],
        permitted: [attachments: [info: [:size]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               attachments: %{info: %{type: "jpg", size: "25M"}},
               name: "Johnny Lawrence"
             }
    end

    test "merges required and permitted in nested lists" do
      params = %{
        "deep" => [
          %{
            "update" => [
              %{
                "description" => "desc 1"
              },
              %{
                "description" => "desc 2",
                "attachments_ids" => ["id 1", "id 2"]
              }
            ]
          }
        ]
      }

      filters = [
        required: [deep: [[update: [[:description]]]]],
        permitted: [deep: [[update: [[:attachments_ids]]]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               deep: [
                 %{
                   update: [
                     %{description: "desc 1"},
                     %{description: "desc 2", attachments_ids: ["id 1", "id 2"]}
                   ]
                 }
               ]
             }
    end

    test "parameters in list" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => [
          %{"name" => "file.jpg"},
          %{"name" => "doc.pdf"}
        ]
      }

      filters = [required: [:name, attachments: [[:name]]]]

      result = Filter.apply(params, filters)

      assert result == %{
               name: "Johnny Lawrence",
               attachments: [
                 %{name: "file.jpg"},
                 %{name: "doc.pdf"}
               ]
             }
    end

    test "parameters in list with nested maps" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => [
          %{
            "name" => "doc.pdf",
            "information" => %{
              "type" => "jpg",
              "size" => "23M",
              "tags" => [
                %{"title" => "important"}
              ]
            }
          }
        ]
      }

      filters = [
        required: [:name, attachments: [[:name, information: [:type, :size, tags: [[:title]]]]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %{
               name: "Johnny Lawrence",
               attachments: [
                 %{
                   name: "doc.pdf",
                   information: %{size: "23M", tags: [%{title: "important"}], type: "jpg"}
                 }
               ]
             }
    end

    test "when a permitted is a map and not given on params" do
      params = %{"name" => "Johnny Lawrence"}

      filters = [permitted: [:name, address: [:street, :city]]]

      result = Filter.apply(params, filters)

      assert result == %{name: "Johnny Lawrence"}
    end

    test "when a permitted is a map and was given a nil on params" do
      params = %{"name" => "Johnny Lawrence", "address" => nil}

      filters = [permitted: [:name, address: [:street, :city]]]

      result = Filter.apply(params, filters)

      assert result == %{name: "Johnny Lawrence", address: %{}}
    end

    test "when a permitted is a map and was given an empty map on params" do
      params = %{"name" => "Johnny Lawrence", "address" => %{}}

      filters = [permitted: [:name, address: [:street, :city]]]

      result = Filter.apply(params, filters)

      assert result == %{name: "Johnny Lawrence", address: %{}}
    end

    test "error in list item" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => [
          %{"other_key" => "file.jpg"},
          %{"name" => "doc.pdf"}
        ]
      }

      filters = [required: [:name, attachments: [[:name]]]]

      result = Filter.apply(params, filters)

      assert result == %Error{
               errors: %{attachments: %{name: "is required"}},
               type: "required"
             }
    end

    test "error when parameter isnt a list" do
      params = %{"name" => "Johnny Lawrence", "attachments" => %{"other_key" => "file.jpg"}}

      filters = [required: [:name, attachments: [[:name]]]]

      result = Filter.apply(params, filters)

      assert result == %Error{errors: %{attachments: "Must be a list"}, type: "type"}
    end

    test "returns error for required field" do
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
          "info" => %{"type" => "jpg", "date" => "invalid"}
        }
      }

      filters = [
        required: [
          :name,
          :nickname,
          address: [:city],
          attachments: [info: [:type, :size, {:date, :date}]]
        ]
      ]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "required",
               errors: %{
                 attachments: %{info: %{size: "is required", date: "is invalid"}},
                 address: %{city: "is required"},
                 nickname: "is required"
               }
             }
    end

    test "empty map and when value is not a map" do
      empty_params = %{}
      params_with_empty_map = %{address: %{}}
      params_with_not_a_map = %{address: []}

      filters = [
        required: [:name, :nickname, address: [:city], attachments: [info: [:type, :size]]]
      ]

      empty_params_result = Filter.apply(empty_params, filters)
      params_with_empty_map_result = Filter.apply(params_with_empty_map, filters)
      params_with_not_a_map_result = Filter.apply(params_with_not_a_map, filters)

      expected_error = %Error{
        type: "required",
        errors: %{
          address: %{city: "is required"},
          attachments: %{
            info: %{size: "is required", type: "is required"}
          },
          nickname: "is required",
          name: "is required"
        }
      }

      assert empty_params_result == expected_error
      assert params_with_empty_map_result == expected_error
      assert params_with_not_a_map_result == expected_error
    end

    test "does not return permitted when required has errors" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{"type" => "jpg"}
        }
      }

      filters = [required: [attachments: [info: [:type, :size]]], permitted: [:name]]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "required",
               errors: %{attachments: %{info: %{size: "is required"}}}
             }
    end

    test "returns error when has required filters and it was given an empty list as params" do
      params = %{"attachments" => []}

      filters = [
        required: [attachments: [[:info, address: [:street, :city]]]],
        permitted: [attachments: [[:name]]]
      ]

      result = Filter.apply(params, filters)

      assert result == %StrongParams.Error{
               errors: %{attachments: %{address: "is required", info: "is required"}},
               type: "required"
             }
    end

    test "returns error for forbidden params when opt is given" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, required: [:name, :description], forbidden_params_err: true)

      assert result == %Error{
               type: "forbidden",
               errors: %{"role" => "is not a permitted parameter"}
             }
    end

    test "returns error for forbidden params when opt is given (multiple errors)" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, required: [:name], forbidden_params_err: true)

      assert result == %Error{
               type: "forbidden",
               errors: %{
                 "role" => "is not a permitted parameter",
                 "description" => "is not a permitted parameter"
               }
             }
    end

    test "returns error for forbidden params when opt is given (with nested params)" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{
            "type" => "jpg",
            "id" => "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
            "date" => "2021-11-29"
          }
        }
      }

      filters = [
        required: [
          :name,
          address: [:street],
          attachments: [info: [:date, :type]]
        ],
        forbidden_params_err: true
      ]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "forbidden",
               errors: %{"attachments" => %{"info" => %{"id" => "is not a permitted parameter"}}}
             }
    end

    test "returns error for forbidden params when opt is given (multiple errors and nested params)" do
      params = %{
        "name" => "Johnny Lawrence",
        "address" => %{
          "street" => "First Avenue"
        },
        "attachments" => %{
          "info" => %{
            "type" => "jpg",
            "id" => "6bb35d22-9c97-4f1f-baf5-2caf0bab9110",
            "date" => "2021-11-29"
          }
        }
      }

      filters = [
        required: [
          address: [:street],
          attachments: [info: [:date]]
        ],
        forbidden_params_err: true
      ]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "forbidden",
               errors: %{
                 "attachments" => %{
                   "info" => %{
                     "id" => "is not a permitted parameter",
                     "type" => "is not a permitted parameter"
                   }
                 },
                 "name" => "is not a permitted parameter"
               }
             }
    end

    test "returns error for forbidden params when opt is given (when parameters has lists)" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => [
          %{
            "name" => "doc.pdf",
            "information" => %{
              "type" => "jpg",
              "size" => "23M",
              "tags" => [
                %{"title" => "important"},
                %{"title" => "important", "deleted" => true}
              ]
            }
          }
        ]
      }

      filters = [
        required: [:name, attachments: [[:name, information: [:type, :size, tags: [[:title]]]]]],
        forbidden_params_err: true
      ]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "forbidden",
               errors: %{
                 "attachments" => %{
                   "information" => %{"tags" => %{"deleted" => "is not a permitted parameter"}}
                 }
               }
             }
    end

    test "returns error for forbidden params when opt is given (when parameters has lists with multiple errors)" do
      params = %{
        "name" => "Johnny Lawrence",
        "attachments" => [
          %{
            "name" => "doc.pdf",
            "extension" => "pdf",
            "information" => %{
              "type" => "jpg",
              "size" => "23M",
              "tags" => [
                %{"title" => "important"},
                %{"title" => "language", "deleted" => true},
                %{"title" => "marketing", "deleted" => true, "root" => true}
              ]
            }
          }
        ]
      }

      filters = [
        required: [attachments: [[:name, information: [:type, :size, tags: [[:title]]]]]],
        forbidden_params_err: true
      ]

      result = Filter.apply(params, filters)

      assert result == %Error{
               type: "forbidden",
               errors: %{
                 "name" => "is not a permitted parameter",
                 "attachments" => %{
                   "extension" => "is not a permitted parameter",
                   "information" => %{
                     "tags" => %{
                       "deleted" => "is not a permitted parameter",
                       "root" => "is not a permitted parameter"
                     }
                   }
                 }
               }
             }
    end

    test "when forbidden_params_err is true but filter already failed" do
      params = %{
        "name" => "Johnny Lawrence",
        "description" => "user description",
        "role" => "admin"
      }

      result = Filter.apply(params, required: [:name, :last_name], forbidden_params_err: true)

      assert result == %Error{type: "required", errors: %{last_name: "is required"}}
    end
  end
end
