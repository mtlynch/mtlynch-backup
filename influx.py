import logging

import influxdb

logger = logging.getLogger(__name__)

class InfluxWriter:
    def __init__(self, host, port, database):
        self._client = influxdb.InfluxDBClient(host=host, port=port, database=database)

    def write_measurement(self, measurement_name, measurement_value, repo):
        logger.info(f'writing measurement to influx: {measurement_name}={measurement_value} ({repo})')
        self._client.write_points(
            [
                {
                    'measurement': measurement_name,
                    'tags': {
                        'host': 'MELLING',
                        'repo': repo,
                    },
                    'fields': {
                        'value': measurement_value,
                    }
                },
            ]
        )
