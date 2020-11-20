import argparse


def run_shell(args):
    """
    Open shell access to Airflow's worker. This allows you to test commands in the context of
    the Airflow instance.
    """
    print("Shell", args)


def run_info(args):
    """
    Run arbitrary command on the Airflow worker.

    Example:

    To list current running process, run:
    pianka.py run -- ps -aux

    To list DAGs, run:
    pianka.py run -- airflow list_dags
    """
    print("Info", args)


def run_mysql(args):
    """
    Starts the MySQL console. Additional parameters are passed to the mysql client.

    Tip:
    If you want to execute "SELECT 123" query, run following command:
    pianka.sh mysql -- --execute="SELECT 123"
    """
    print("MySQL", args)


def ger_parser():
    parser = argparse.ArgumentParser(
        description="Process some integers.", formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-C",
        "--composer-name",
        const="c",
        action="store_const",
        help="Composer instance used to run the operations on.",
    )
    parser.add_argument(
        "-L", "--composer-location", const="c", action="store_const", help="Composer location"
    )
    subparsers = parser.add_subparsers(help="sub-command help", metavar="COMMAND")
    subparsers.required = True
    parser_a = subparsers.add_parser("shell", help=run_shell.__doc__)
    parser_a.set_defaults(func=run_shell)
    parser_b = subparsers.add_parser("info", help=run_info.__doc__)
    parser_b.set_defaults(func=run_info)
    parser_c = subparsers.add_parser("mysql", help=run_mysql.__doc__)
    parser_c.set_defaults(func=run_info)
    return parser


parser = ger_parser()

args = parser.parse_args()
args.func(args)
