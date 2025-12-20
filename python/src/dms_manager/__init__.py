"""
DMS Manager Module
Provides utilities for managing AWS DMS tasks, endpoints, and replication instances
"""

import boto3
import logging
from typing import Dict, List, Optional, Any
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class DMSManager:
    """Manager class for AWS DMS operations"""

    def __init__(self, region_name: str = 'us-east-1', profile_name: Optional[str] = None):
        """
        Initialize DMS Manager
        
        Args:
            region_name: AWS region name
            profile_name: AWS profile name (optional)
        """
        session = boto3.Session(
            region_name=region_name,
            profile_name=profile_name
        )
        self.dms_client = session.client('dms')
        self.region_name = region_name
        logger.info(f"Initialized DMS Manager for region: {region_name}")

    def create_endpoint(
        self,
        endpoint_identifier: str,
        endpoint_type: str,
        engine_name: str,
        server_name: str,
        port: int,
        database_name: str,
        username: str,
        password: str,
        ssl_mode: str = 'require',
        extra_connection_attributes: str = '',
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create a DMS endpoint
        
        Args:
            endpoint_identifier: Unique identifier for the endpoint
            endpoint_type: Type of endpoint ('source' or 'target')
            engine_name: Database engine name
            server_name: Server hostname or IP
            port: Database port
            database_name: Database name
            username: Database username
            password: Database password
            ssl_mode: SSL mode for connection
            extra_connection_attributes: Additional connection attributes
            
        Returns:
            Dict containing endpoint information
        """
        try:
            response = self.dms_client.create_endpoint(
                EndpointIdentifier=endpoint_identifier,
                EndpointType=endpoint_type,
                EngineName=engine_name,
                ServerName=server_name,
                Port=port,
                DatabaseName=database_name,
                Username=username,
                Password=password,
                SslMode=ssl_mode,
                ExtraConnectionAttributes=extra_connection_attributes,
                **kwargs
            )
            logger.info(f"Created endpoint: {endpoint_identifier}")
            return response['Endpoint']
        except ClientError as e:
            logger.error(f"Error creating endpoint: {e}")
            raise

    def test_connection(
        self,
        replication_instance_arn: str,
        endpoint_arn: str
    ) -> Dict[str, Any]:
        """
        Test connection to an endpoint
        
        Args:
            replication_instance_arn: ARN of the replication instance
            endpoint_arn: ARN of the endpoint to test
            
        Returns:
            Dict containing connection test results
        """
        try:
            response = self.dms_client.test_connection(
                ReplicationInstanceArn=replication_instance_arn,
                EndpointArn=endpoint_arn
            )
            logger.info(f"Testing connection for endpoint: {endpoint_arn}")
            return response['Connection']
        except ClientError as e:
            logger.error(f"Error testing connection: {e}")
            raise

    def create_replication_task(
        self,
        task_identifier: str,
        source_endpoint_arn: str,
        target_endpoint_arn: str,
        replication_instance_arn: str,
        migration_type: str,
        table_mappings: str,
        task_settings: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create a DMS replication task
        
        Args:
            task_identifier: Unique identifier for the task
            source_endpoint_arn: ARN of source endpoint
            target_endpoint_arn: ARN of target endpoint
            replication_instance_arn: ARN of replication instance
            migration_type: Type of migration (full-load, cdc, full-load-and-cdc)
            table_mappings: JSON string with table mapping rules
            task_settings: JSON string with task settings (optional)
            
        Returns:
            Dict containing task information
        """
        try:
            params = {
                'ReplicationTaskIdentifier': task_identifier,
                'SourceEndpointArn': source_endpoint_arn,
                'TargetEndpointArn': target_endpoint_arn,
                'ReplicationInstanceArn': replication_instance_arn,
                'MigrationType': migration_type,
                'TableMappings': table_mappings,
            }
            
            if task_settings:
                params['ReplicationTaskSettings'] = task_settings
                
            params.update(kwargs)
            
            response = self.dms_client.create_replication_task(**params)
            logger.info(f"Created replication task: {task_identifier}")
            return response['ReplicationTask']
        except ClientError as e:
            logger.error(f"Error creating replication task: {e}")
            raise

    def start_replication_task(
        self,
        task_arn: str,
        start_type: str = 'start-replication'
    ) -> Dict[str, Any]:
        """
        Start a replication task
        
        Args:
            task_arn: ARN of the task to start
            start_type: Type of start (start-replication, resume-processing, reload-target)
            
        Returns:
            Dict containing task information
        """
        try:
            response = self.dms_client.start_replication_task(
                ReplicationTaskArn=task_arn,
                StartReplicationTaskType=start_type
            )
            logger.info(f"Started replication task: {task_arn}")
            return response['ReplicationTask']
        except ClientError as e:
            logger.error(f"Error starting replication task: {e}")
            raise

    def stop_replication_task(self, task_arn: str) -> Dict[str, Any]:
        """
        Stop a replication task
        
        Args:
            task_arn: ARN of the task to stop
            
        Returns:
            Dict containing task information
        """
        try:
            response = self.dms_client.stop_replication_task(
                ReplicationTaskArn=task_arn
            )
            logger.info(f"Stopped replication task: {task_arn}")
            return response['ReplicationTask']
        except ClientError as e:
            logger.error(f"Error stopping replication task: {e}")
            raise

    def describe_replication_tasks(
        self,
        filters: Optional[List[Dict[str, Any]]] = None
    ) -> List[Dict[str, Any]]:
        """
        Describe replication tasks
        
        Args:
            filters: Optional filters for tasks
            
        Returns:
            List of task information dictionaries
        """
        try:
            params = {}
            if filters:
                params['Filters'] = filters
                
            response = self.dms_client.describe_replication_tasks(**params)
            return response['ReplicationTasks']
        except ClientError as e:
            logger.error(f"Error describing replication tasks: {e}")
            raise

    def get_task_status(self, task_arn: str) -> str:
        """
        Get status of a replication task
        
        Args:
            task_arn: ARN of the task
            
        Returns:
            Task status string
        """
        try:
            tasks = self.describe_replication_tasks(
                filters=[
                    {
                        'Name': 'replication-task-arn',
                        'Values': [task_arn]
                    }
                ]
            )
            if tasks:
                return tasks[0]['Status']
            return 'unknown'
        except ClientError as e:
            logger.error(f"Error getting task status: {e}")
            raise

    def delete_replication_task(self, task_arn: str) -> Dict[str, Any]:
        """
        Delete a replication task
        
        Args:
            task_arn: ARN of the task to delete
            
        Returns:
            Dict containing task information
        """
        try:
            response = self.dms_client.delete_replication_task(
                ReplicationTaskArn=task_arn
            )
            logger.info(f"Deleted replication task: {task_arn}")
            return response['ReplicationTask']
        except ClientError as e:
            logger.error(f"Error deleting replication task: {e}")
            raise
