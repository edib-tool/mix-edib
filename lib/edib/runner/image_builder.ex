defmodule EDIB.Runner.ImageBuilder do
  @moduledoc false

  import EDIB.Utils

  def run({:ok, _, options}) do
    {:ok, :init_image_build, options}
    |> read_config
    |> build_commands
    |> print_info("Creating docker image ...")
    |> run_commands
    |> package_summary
  end
  def run(error), do: error

  ### Internals

  defp read_config({:ok, _msg, options}) do
    config_file = EDIB.Defaults.artifact_config_path
    case EDIB.BuildConfig.Image.from_config_file(config_file) do
      {:ok, config} ->
        {:ok, :config_loaded, {config, options}}
      error ->
        error
    end
  end
  defp read_config(error), do: error

  defp build_commands({:ok, _msg, {config, options}}) do
    config
    |> EDIB.BuildConfig.Image.to_commands
    |> maybe_build_commands(config, options)
  end
  defp build_commands(error), do: error

  defp maybe_build_commands({:ok, commands}, config, options),
    do: {:ok, :image_commands, {commands, config, options}}
  defp maybe_build_commands(error, _, _),
    do: error

  defp run_commands({:ok, _msg, {commands, config, options}}) do
    commands
    |> Enum.reduce(
      {:ok, :command_loop, {config, options}},
      &run_command/2)
  end
  defp run_commands(error), do: error

  defp run_command(command, {:ok, _msg, {config, options}}) do
    options.writer.("$> #{command}\n")
    command
    |> do_cmd(options.writer)
    |> after_run_command(command, {config, options})
  end
  defp run_command(_command, error), do: error

  defp after_run_command(0, _command, state),
    do: {:ok, :command_success, state}
  defp after_run_command(_, command, state),
    do: {:error, "Image command '#{command}' failed", state}

  defp package_summary({:ok, _msg, {config, options}}) do
    tagged_name = ~s(#{config.name}:#{config.tag})
    latest_name = ~s(#{config.name}:latest)
    info("Docker image created: #{tagged_name} (#{latest_name})")

    usage_info = """

        You can try your freshly packaged image with:

        $ docker run --rm #{tagged_name}

        Or if you have a Phoenix app:

        $ docker run --rm -e "PORT=4000" -p 4000:4000 #{tagged_name}

    """
    print(usage_info)
    {:ok, :summary, options}
  end
  defp package_summary(error), do: error
end
