defmodule Firestore do
  alias Goth.Token
  alias Google.Firestore.V1

  @database "projects/gele-b64ed/databases/(default)"
  @parent "#{@database}/documents"
  @scopes ["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/datastore"]

  defp get_token do
    @scopes
    |> Enum.join(" ")
    |> Token.for_scope()
  end

  defp create_channel do
    {:ok, token} = get_token()

    # Read CA certificate for certificate pinning
    root = File.cwd!
    ca_path = "#{root}/priv/certs/edgecert-googleapis-com.pem"

    # Prepare options for the client
    opts = [
      interceptors: [GRPC.Logger.Client],
      cred: GRPC.Credential.new(ssl: [cacertfile: ca_path]),
      headers: [
        "Authorization": "#{token.type} #{token.token}" 
      ]
    ]
    # Create the client
    GRPC.Stub.connect("firestore.googleapis.com:443", opts)
  end

  def list_collection_ids(channel) do
    request = V1.ListCollectionIdsRequest.new(
      parent: @parent,
      page_size: 10
    )

    V1.Firestore.Stub.list_collection_ids(channel, request, content_type: "application/grpc")
  end

  def list_documents(channel, collection) do
    request = V1.ListDocumentsRequest.new(
      parent: @parent,
      page_size: 10_000,
      collection_id: collection
    )

    V1.Firestore.Stub.list_documents(channel, request, content_type: "application/grpc")
  end

  @doc """
  https://firebase.google.com/docs/firestore/reference/rpc/google.firestore.v1#google.firestore.v1.Firestore.CreateDocument
  """
  def create_document(channel, collection, document) do
    request = V1.CreateDocumentRequest.new(
      parent: @parent,
      collection_id: collection,
      document: document
    )

    V1.Firestore.Stub.create_document(channel, request, content_type: "application/grpc")
  end

  @doc """
  https://firebase.google.com/docs/firestore/reference/rpc/google.firestore.v1#google.firestore.v1.Firestore.Listen
  """
  def listen(channel) do
    document_target = V1.Target.DocumentsTarget.new(
      documents: ["projects/gele-b64ed/databases/(default)/documents/vehicles/4225Ii69RoVYF0ddSKvw"]
    )
    target = V1.Target.new(
      target_type: {:documents, document_target}
    )
    request = V1.ListenRequest.new(
      database: @database,
      target_change: {:add_target, target}
    )
    |> IO.inspect

    stream = V1.Firestore.Stub.listen(channel)
    GRPC.Stub.send_request(stream, request, end_stream: true)
    do_listen(stream)
  end

  defp do_listen(stream) do
    {:ok, reply_enum} = GRPC.Stub.recv(stream)
    replies = Enum.map(reply_enum, fn({:ok, reply}) -> reply end)
              |> IO.inspect
    do_listen(stream)
  end

  def hello do
    {:ok, channel} = create_channel()

    {:ok, reply} = list_collection_ids(channel)

    last_collection = List.last(reply.collection_ids)
    {:ok, reply} = list_documents(channel, last_collection)

    List.last(reply.documents)
    |> IO.inspect

    # Enum.each(0..10, fn _ ->
    #   uuid = UUID.uuid1()

    #   value = V1.Value.new(
    #     value_type: {:string_value, uuid}
    #   )

    #   document = V1.Document.new(
    #     fields: %{"name" => value} 
    #   )

    #   create_document(channel, "vehicles", document)
    # end)

    listen(channel)

    # reply.documents
    # |> Enum.count()
    # |> IO.inspect
  end
end
