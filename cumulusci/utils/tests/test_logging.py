import os
import sys
from unittest.mock import patch, Mock
from pathlib import Path

from cumulusci.utils.logging import (
    tee_stdout_stderr,
    get_gist_logger,
    get_rot_file_logger,
)


class TestUtilLogging:
    @patch("cumulusci.utils.logging.get_gist_logger")
    def test_tee_stdout_stderr(self, gist_logger):
        args = ["cci", "test"]
        logger = Mock(handlers=[Mock()])
        gist_logger.return_value = Mock()
        # Setup temp logfile
        tempfile = "tempfile.log"
        log_content = "This is the content for the temp log file."
        with open(tempfile, "w") as f:
            f.write(log_content)

        expected_stdout_text = "This is expected stdout.\n"
        expected_stderr_text = "This is expected stderr.\n"
        with tee_stdout_stderr(args, logger, tempfile):
            sys.stdout.write(expected_stdout_text)
            sys.stderr.write(expected_stderr_text)

        assert gist_logger.called_once()
        assert logger.debug.call_count == 3
        assert logger.debug.call_args_list[0][0][0] == "cci test\n"
        assert logger.debug.call_args_list[1][0][0] == expected_stdout_text
        assert logger.debug.call_args_list[2][0][0] == expected_stderr_text
        # temp log file should be deleted
        assert not os.path.isfile(tempfile)

    @patch("cumulusci.utils.logging.Path.mkdir")
    @patch("cumulusci.utils.logging.Path.home")
    @patch("cumulusci.utils.logging.get_rot_file_logger")
    def test_get_gist_logger(self, file_logger, home, mkdir):
        home.return_value = Path("/Users/bob.ross")
        get_gist_logger()
        file_logger.assert_called_once_with(
            "stdout/stderr", Path("/Users/bob.ross/.cumulusci/logs/cci.log")
        )

    @patch("cumulusci.utils.logging.RotatingFileHandler")
    @patch("cumulusci.utils.logging.logging")
    def test_get_rot_file_logger(self, logging, rot_filehandler):
        logger_name = "The happy logger"
        path = "happy/logger/path"
        logger = get_rot_file_logger(logger_name, path)

        logging.getLogger.assert_called_once_with(logger_name)
        rot_filehandler.assert_called_once_with(path, backupCount=5, encoding="utf-8")
        logger.addHandler.assert_called_once()
        logger.setLevel.assert_called_once()
