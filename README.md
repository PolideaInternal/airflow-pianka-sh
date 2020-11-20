# pianka.sh

A little script that helps you manage your Cloud Composer instances. This just fills gapps in the [gcloud](https://cloud.google.com/sdk/docs/downloads-versioned-archives) tool.


##  Installation

```
curl https://github.com/PolideaInternal/airflow-pianka-sh/blob/master/pianka.sh > ./pianka.sh
chmod +x ./pianka.sh
```
Optionally, you can also install this script globally. This will allow you to use this script from
any location.
```
mv pianka.sh /usr/local/bin/pianka.sh
```

## Feature

* Open shell access to Airflow's worker.
* Run arbitrary command on the Airflow worker.
* Starts the MySQL console.
* More features coming soon

## Known issues

Cloud Composer instances using private IP are not supported

## Usage

<!--- START USAGE MARKER -->
````
Usage: pianka.sh [-h] [-C] [-L] [-v] <command>

Help manage Cloud Composer instances

The script is adapted to work properly when added to the PATH variable. This will allow you to use
this script from any location.

Flags:

-h, --help
        Shows this help message.
-C, --composer-name <COMPOSER_NAME>
        Composer instance used to run the operations on. Defaults to
-L, --composer-location <COMPOSER_LOCATION>
        Composer locations. Defaults to
-v, --verbose
        Add even more verbosity when running the script.


These are supported commands used in various situations:

shell
        Open shell access to Airflow's worker. This allows you to test commands in the context of
        the Airflow instance.

info
        Print basic information about the environment.

run
        Run arbitrary command on the Airflow worker.

        Example:
        If you want to list currnet running process, run:
        pianka.sh run -- ps -aux

        If you want to list DAGs, run:
        pianka.sh run -- airflow list_dags

mysql
        Starts the MySQL console.

        Additional parameters are passed to the mysql client.

        Example:
        If you want to execute "SELECT 123" query, run:
        pianka.sh mysql -- --execute="SELECT 123"

mysqltunnel
        Starts the tunnel to MySQL database.

        This allows you to connect to the database with any tool, including your IDE.
mysqldump
        Dumps database or selected table(s).

        Additional parameters are passed to the mysqldump.

        To dump "connection" table to "connection.sql" file, run:

        pianka.sh mysqldump -- --column-statistics=0  connection > connection.sql

        Reference:
        https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html

help
        Print help

````
<!--- END USAGE MARKER -->
