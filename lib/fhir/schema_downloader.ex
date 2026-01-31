defmodule FHIR.SchemaDownloader do
  @moduledoc """
  Utilities for downloading machine-readable schema definition files.
  """

  @doc """
  Given a list of versions, if they have not been downloaded yet, download and extract them.
  """
  @spec download_and_extract!(list(), String.t()) :: :ok
  def download_and_extract!(versions, base_directory) do
    Application.ensure_started(:telemetry)

    Finch.start_link(name: FHIR.SchemaDownloaderFinch)

    IO.puts("FHIR compiler: starting download/extract.")

    versions
    |> Enum.reject(fn version ->
      version_spec_directory = Path.join([base_directory, version])

      exists = File.exists?(version_spec_directory)

      if exists do
        IO.puts(
          "FHIR compiler: Skipping download/extract for #{version} as #{version_spec_directory} already exists."
        )
      end

      exists
    end)
    |> Enum.each(fn version ->
      IO.puts("FHIR compiler: Fetching definitions for #{version}.")

      Finch.build(:get, "http://hl7.org/fhir/#{version}/definitions.json.zip")
      |> Finch.request!(FHIR.SchemaDownloaderFinch)
      |> then(fn %{body: body} ->
        archive_path = Path.join([base_directory, "#{version}.zip"])
        subarchive_path = Path.join([base_directory, version, "fhir.schema.json.zip"])
        unzip_path = Path.join([base_directory, version])

        IO.puts("FHIR compiler: Unzip into #{unzip_path}.")
        File.mkdir_p!(unzip_path)
        File.write!(archive_path, body)

        {:ok, _} = :zip.unzip(to_charlist(archive_path), cwd: to_charlist(unzip_path))
        {:ok, _} = :zip.unzip(to_charlist(subarchive_path), cwd: to_charlist(unzip_path))

        IO.puts("FHIR compiler: download/extract done for version #{version}.")
      end)
    end)

    IO.puts("FHIR compiler: download/extract done.")
  end
end
