import os
import tempfile
import vim
import subprocess
from multiprocessing import connection


class Client:
    """
    Starts and connects to a separate Vim instance used for testing motions.

    This is used to test motions in the exact same environment as the user (loaded via
    a temporary session file), without moving the user's cursor in the process. This
    allows pathfinding to happen in the background while the user may continue working.

    A custom vimrc is used to only load this plugin, disabling other plugins and user
    settings.
    """

    def __init__(self):
        self.open()

        # There is no chance of simultaneous pathfinding requests completing in the
        # wrong order, because the server only processes one at a time. Hence we can
        # just use a list to queue up the callback functions.
        self.callback_queue = list()

    def open(self):
        """Launch and connect to the server Vim."""
        # Create a file used to communicate with the server
        self.file_path = os.path.join(
            tempfile.gettempdir(), "pathfinder_vim_" + vim.eval("getpid()")
        )

        # serverrc.vim in the root of the repo
        vimrc_path = os.path.normpath(os.path.join(
            os.path.dirname(__file__), "..", "serverrc.vim"))
        # Launch the server as described above
        self.server_process = subprocess.Popen(
            (
                "vim", "--not-a-term",
                "--cmd", f"let g:pf_server_communiation_file='{self.file_path}'",
                "-u", vimrc_path
            ),
            stdout=subprocess.DEVNULL
        )

        # poll_responses will see this is None and look for the ability to connect
        # instead of received messages
        self.server_connection = None

    def close(self):
        """Shut down the server Vim."""
        if self.server_connection is not None:
            # Server will shut down Vim gracefully when we disconnect
            self.server_connection.close()
        else:
            # Not connected yet, terminate the process instead
            self.server_process.terminate()

    def poll_responses(self):
        if self.server_connection is None:
            # Check if the server has started listening yet
            try:
                self.server_connection = connection.Client(self.file_path)
            except FileNotFoundError:
                pass

        # Check if any data is available to be read
        elif self.server_connection.poll():
            # Get response (sent in a tuple of type, data)
            response_type, data = self.server_connection.recv()
            self.handle_response(response_type, data)

    def handle_response(self, response_type, data):
        """
        Process a response recieved from the server.

        This will be one of:
        - ``RESULT`` - A pathfinding result. Call the first queued callback.
        - ``ERROR`` - An unexpected exception was caught and the server has exited.
          Relay the traceback to the user for debugging.
        """
        if response_type == "RESULT":
            # Get the first callback function and pass the result to it
            self.callback_queue.pop()(data)
        elif response_type == "ERROR":
            print(
                "Pathfinding server encountered an unexpected exception:",
                data, sep="\n"
            )
        else:
            raise Exception("Received an unexpected response " + response_type)

    def pathfind(self, start_view, target_view, callback):
        """
        Request a pathfinding result from the server.

        :param start_view: The start position, in the current window.
        :param target_view: The target position, in the current window.
        :param callback: Function to be called once a path is found. Recieves a list
            of motions as a parameter.
        """
        self.callback_queue.append(callback)

        self.server_connection.send(("START", start_view))
        self.server_connection.send(("TARGET", target_view))
        self.server_connection.send(("MOTIONS", vim.eval("g:pf_motions")))
        self.server_connection.send(("SCROLLOFF", vim.options["scrolloff"]))

        # WindowTextWidth() - see plugin/dimensions.vim
        window_size = (vim.eval("WindowTextWidth()"), vim.eval("winheight(0)"))
        self.server_connection.send(("SIZE", window_size))

        # We don't need to join these lines together with \n, because they need
        # to be used in list form by the server
        buffer_contents = vim.eval("getline(0,'$')")
        self.server_connection.send(("BUFFER", buffer_contents))

        # TODO: Send value of g:pf_motions

        # Ask the server to start pathfinding
        self.server_connection.send(("RUN", None))


client = Client()