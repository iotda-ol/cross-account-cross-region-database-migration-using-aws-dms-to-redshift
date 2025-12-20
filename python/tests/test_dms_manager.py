"""
Unit tests for DMS Manager
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from dms_manager import DMSManager


@pytest.fixture
def dms_manager():
    """Fixture for DMS Manager instance"""
    with patch('boto3.Session'):
        manager = DMSManager(region_name='us-east-1')
        return manager


def test_dms_manager_initialization(dms_manager):
    """Test DMS Manager initialization"""
    assert dms_manager.region_name == 'us-east-1'
    assert dms_manager.dms_client is not None


def test_create_endpoint_success(dms_manager):
    """Test successful endpoint creation"""
    mock_response = {
        'Endpoint': {
            'EndpointArn': 'arn:aws:dms:us-east-1:123456789012:endpoint:test',
            'EndpointIdentifier': 'test-endpoint',
            'EndpointType': 'source',
            'EngineName': 'postgres'
        }
    }
    
    dms_manager.dms_client.create_endpoint = Mock(return_value=mock_response)
    
    result = dms_manager.create_endpoint(
        endpoint_identifier='test-endpoint',
        endpoint_type='source',
        engine_name='postgres',
        server_name='test.rds.amazonaws.com',
        port=5432,
        database_name='testdb',
        username='testuser',
        password='testpass'
    )
    
    assert result['EndpointIdentifier'] == 'test-endpoint'
    assert result['EndpointType'] == 'source'


def test_create_replication_task_success(dms_manager):
    """Test successful replication task creation"""
    mock_response = {
        'ReplicationTask': {
            'ReplicationTaskArn': 'arn:aws:dms:us-east-1:123456789012:task:test',
            'ReplicationTaskIdentifier': 'test-task',
            'Status': 'creating'
        }
    }
    
    dms_manager.dms_client.create_replication_task = Mock(return_value=mock_response)
    
    result = dms_manager.create_replication_task(
        task_identifier='test-task',
        source_endpoint_arn='arn:aws:dms:us-east-1:123456789012:endpoint:source',
        target_endpoint_arn='arn:aws:dms:us-east-1:123456789012:endpoint:target',
        replication_instance_arn='arn:aws:dms:us-east-1:123456789012:rep:instance',
        migration_type='full-load',
        table_mappings='{"rules": []}'
    )
    
    assert result['ReplicationTaskIdentifier'] == 'test-task'
    assert result['Status'] == 'creating'


def test_start_replication_task_success(dms_manager):
    """Test successful task start"""
    mock_response = {
        'ReplicationTask': {
            'Status': 'starting'
        }
    }
    
    dms_manager.dms_client.start_replication_task = Mock(return_value=mock_response)
    
    result = dms_manager.start_replication_task(
        task_arn='arn:aws:dms:us-east-1:123456789012:task:test'
    )
    
    assert result['Status'] == 'starting'


def test_get_task_status_success(dms_manager):
    """Test getting task status"""
    mock_response = {
        'ReplicationTasks': [
            {
                'Status': 'running',
                'ReplicationTaskArn': 'arn:aws:dms:us-east-1:123456789012:task:test'
            }
        ]
    }
    
    dms_manager.dms_client.describe_replication_tasks = Mock(return_value=mock_response)
    
    status = dms_manager.get_task_status(
        task_arn='arn:aws:dms:us-east-1:123456789012:task:test'
    )
    
    assert status == 'running'


def test_test_connection_success(dms_manager):
    """Test connection testing"""
    mock_response = {
        'Connection': {
            'Status': 'successful'
        }
    }
    
    dms_manager.dms_client.test_connection = Mock(return_value=mock_response)
    
    result = dms_manager.test_connection(
        replication_instance_arn='arn:aws:dms:us-east-1:123456789012:rep:instance',
        endpoint_arn='arn:aws:dms:us-east-1:123456789012:endpoint:test'
    )
    
    assert result['Status'] == 'successful'
