"""
Monitoring Module
Provides utilities for monitoring DMS tasks and database metrics
"""

import boto3
import logging
import time
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class DMSMonitor:
    """Monitor class for DMS tasks and CloudWatch metrics"""

    def __init__(
        self,
        region_name: str = 'us-east-1',
        profile_name: Optional[str] = None
    ):
        """
        Initialize DMS Monitor
        
        Args:
            region_name: AWS region name
            profile_name: AWS profile name (optional)
        """
        session = boto3.Session(
            region_name=region_name,
            profile_name=profile_name
        )
        self.dms_client = session.client('dms')
        self.cloudwatch_client = session.client('cloudwatch')
        self.logs_client = session.client('logs')
        self.region_name = region_name

    def get_task_metrics(
        self,
        task_id: str,
        metric_names: Optional[List[str]] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        period: int = 300
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        Get CloudWatch metrics for a DMS task
        
        Args:
            task_id: Task identifier
            metric_names: List of metric names to retrieve
            start_time: Start time for metrics
            end_time: End time for metrics
            period: Period in seconds
            
        Returns:
            Dictionary of metrics data
        """
        if metric_names is None:
            metric_names = [
                'FullLoadThroughputRowsSource',
                'FullLoadThroughputRowsTarget',
                'CDCLatencySource',
                'CDCLatencyTarget',
                'NetworkTransmitThroughput',
                'NetworkReceiveThroughput'
            ]

        if start_time is None:
            start_time = datetime.utcnow() - timedelta(hours=1)
        if end_time is None:
            end_time = datetime.utcnow()

        metrics_data = {}

        try:
            for metric_name in metric_names:
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace='AWS/DMS',
                    MetricName=metric_name,
                    Dimensions=[
                        {
                            'Name': 'ReplicationTaskIdentifier',
                            'Value': task_id
                        }
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=period,
                    Statistics=['Average', 'Maximum', 'Minimum']
                )
                metrics_data[metric_name] = response['Datapoints']
                logger.info(f"Retrieved {len(response['Datapoints'])} datapoints for {metric_name}")

        except ClientError as e:
            logger.error(f"Error retrieving metrics: {e}")
            raise

        return metrics_data

    def get_replication_lag(self, task_arn: str) -> Optional[float]:
        """
        Get current replication lag for a task
        
        Args:
            task_arn: ARN of the replication task
            
        Returns:
            Replication lag in seconds, or None if not available
        """
        try:
            # Get task statistics
            response = self.dms_client.describe_replication_tasks(
                Filters=[
                    {
                        'Name': 'replication-task-arn',
                        'Values': [task_arn]
                    }
                ]
            )

            if response['ReplicationTasks']:
                task = response['ReplicationTasks'][0]
                stats = task.get('ReplicationTaskStats', {})
                
                # Calculate lag from statistics
                elapsed_time = stats.get('ElapsedTimeMillis', 0)
                fresh_start_date = stats.get('FreshStartDate')
                full_load_start_date = stats.get('FullLoadStartDate')
                
                if fresh_start_date and full_load_start_date:
                    lag = (datetime.utcnow() - full_load_start_date).total_seconds()
                    return lag

            return None

        except ClientError as e:
            logger.error(f"Error getting replication lag: {e}")
            raise

    def get_task_logs(
        self,
        task_id: str,
        log_group_name: Optional[str] = None,
        limit: int = 100,
        tail: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Get CloudWatch logs for a DMS task
        
        Args:
            task_id: Task identifier
            log_group_name: CloudWatch log group name
            limit: Maximum number of log events to retrieve
            tail: Return the most recent logs
            
        Returns:
            List of log events
        """
        if log_group_name is None:
            log_group_name = f"/aws/dms/tasks/{task_id}"

        try:
            # Get log streams
            streams_response = self.logs_client.describe_log_streams(
                logGroupName=log_group_name,
                orderBy='LastEventTime',
                descending=True,
                limit=1
            )

            if not streams_response['logStreams']:
                logger.warning(f"No log streams found for {log_group_name}")
                return []

            log_stream_name = streams_response['logStreams'][0]['logStreamName']

            # Get log events
            events_response = self.logs_client.get_log_events(
                logGroupName=log_group_name,
                logStreamName=log_stream_name,
                limit=limit,
                startFromHead=not tail
            )

            return events_response['events']

        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                logger.warning(f"Log group not found: {log_group_name}")
                return []
            logger.error(f"Error retrieving logs: {e}")
            raise

    def monitor_task_progress(
        self,
        task_arn: str,
        interval: int = 60,
        max_iterations: Optional[int] = None
    ) -> None:
        """
        Monitor task progress continuously
        
        Args:
            task_arn: ARN of the task to monitor
            interval: Monitoring interval in seconds
            max_iterations: Maximum number of iterations (None for infinite)
        """
        iteration = 0
        
        try:
            while max_iterations is None or iteration < max_iterations:
                # Get task status
                response = self.dms_client.describe_replication_tasks(
                    Filters=[
                        {
                            'Name': 'replication-task-arn',
                            'Values': [task_arn]
                        }
                    ]
                )

                if response['ReplicationTasks']:
                    task = response['ReplicationTasks'][0]
                    status = task['Status']
                    stats = task.get('ReplicationTaskStats', {})
                    
                    logger.info(
                        f"Task Status: {status} | "
                        f"Full Load Progress: {stats.get('FullLoadProgressPercent', 0)}% | "
                        f"Tables Loaded: {stats.get('TablesLoaded', 0)} | "
                        f"Tables Loading: {stats.get('TablesLoading', 0)} | "
                        f"Tables Queued: {stats.get('TablesQueued', 0)} | "
                        f"Tables Errored: {stats.get('TablesErrored', 0)}"
                    )

                    if status in ['stopped', 'failed', 'deleting']:
                        logger.warning(f"Task reached terminal status: {status}")
                        break

                time.sleep(interval)
                iteration += 1

        except KeyboardInterrupt:
            logger.info("Monitoring interrupted by user")
        except ClientError as e:
            logger.error(f"Error monitoring task: {e}")
            raise

    def create_cloudwatch_dashboard(
        self,
        dashboard_name: str,
        task_ids: List[str]
    ) -> str:
        """
        Create a CloudWatch dashboard for DMS tasks
        
        Args:
            dashboard_name: Name for the dashboard
            task_ids: List of task identifiers to include
            
        Returns:
            Dashboard ARN
        """
        widgets = []
        
        # Create widgets for each task
        for idx, task_id in enumerate(task_ids):
            # Throughput widget
            widgets.append({
                "type": "metric",
                "x": 0,
                "y": idx * 6,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["AWS/DMS", "FullLoadThroughputRowsSource", 
                         {"stat": "Average", "label": "Source Throughput"}],
                        [".", "FullLoadThroughputRowsTarget", 
                         {"stat": "Average", "label": "Target Throughput"}]
                    ],
                    "view": "timeSeries",
                    "region": self.region_name,
                    "title": f"Throughput - {task_id}",
                    "period": 300
                }
            })
            
            # Latency widget
            widgets.append({
                "type": "metric",
                "x": 12,
                "y": idx * 6,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["AWS/DMS", "CDCLatencySource", 
                         {"stat": "Average", "label": "CDC Latency"}]
                    ],
                    "view": "timeSeries",
                    "region": self.region_name,
                    "title": f"CDC Latency - {task_id}",
                    "period": 300
                }
            })

        dashboard_body = {
            "widgets": widgets
        }

        try:
            response = self.cloudwatch_client.put_dashboard(
                DashboardName=dashboard_name,
                DashboardBody=str(dashboard_body)
            )
            logger.info(f"Created dashboard: {dashboard_name}")
            return response['DashboardArn']
        except ClientError as e:
            logger.error(f"Error creating dashboard: {e}")
            raise
