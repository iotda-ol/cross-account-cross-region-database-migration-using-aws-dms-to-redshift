"""
Unit tests for Data Validator
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from validators import DataValidator, ValidationResult


@pytest.fixture
def validator():
    """Fixture for DataValidator instance"""
    source_config = {
        'host': 'source.rds.amazonaws.com',
        'port': 5432,
        'database': 'sourcedb',
        'username': 'testuser',
        'password': 'testpass'
    }
    
    target_config = {
        'host': 'target.redshift.amazonaws.com',
        'port': 5439,
        'database': 'targetdb',
        'username': 'admin',
        'password': 'adminpass'
    }
    
    return DataValidator(source_config, target_config)


def test_validator_initialization(validator):
    """Test DataValidator initialization"""
    assert validator.source_config['database'] == 'sourcedb'
    assert validator.target_config['database'] == 'targetdb'
    assert validator.source_conn is None
    assert validator.target_conn is None


@patch('validators.psycopg2.connect')
def test_connect_source_success(mock_connect, validator):
    """Test successful source connection"""
    mock_conn = Mock()
    mock_connect.return_value = mock_conn
    
    validator.connect_source()
    
    assert validator.source_conn == mock_conn
    mock_connect.assert_called_once()


@patch('validators.redshift_connector.connect')
def test_connect_target_success(mock_connect, validator):
    """Test successful target connection"""
    mock_conn = Mock()
    mock_connect.return_value = mock_conn
    
    validator.connect_target()
    
    assert validator.target_conn == mock_conn
    mock_connect.assert_called_once()


def test_validation_result_dataclass():
    """Test ValidationResult dataclass"""
    result = ValidationResult(
        table_name='public.users',
        source_count=1000,
        target_count=1000,
        is_valid=True,
        discrepancy=0,
        message='Valid'
    )
    
    assert result.table_name == 'public.users'
    assert result.source_count == 1000
    assert result.target_count == 1000
    assert result.is_valid is True
    assert result.discrepancy == 0
    assert result.message == 'Valid'


@patch('validators.psycopg2.connect')
@patch('validators.redshift_connector.connect')
def test_validate_row_counts_matching(mock_redshift, mock_postgres, validator):
    """Test row count validation with matching counts"""
    # Setup mock connections
    mock_source_conn = Mock()
    mock_target_conn = Mock()
    mock_postgres.return_value = mock_source_conn
    mock_redshift.return_value = mock_target_conn
    
    # Setup mock cursors
    mock_source_cursor = Mock()
    mock_target_cursor = Mock()
    mock_source_conn.cursor.return_value = mock_source_cursor
    mock_target_conn.cursor.return_value = mock_target_cursor
    
    # Mock fetchone to return count
    mock_source_cursor.fetchone.return_value = [1000]
    mock_target_cursor.fetchone.return_value = [1000]
    
    tables = [{'schema': 'public', 'table': 'users'}]
    results = validator.validate_row_counts(tables)
    
    assert len(results) == 1
    assert results[0].is_valid is True
    assert results[0].source_count == 1000
    assert results[0].target_count == 1000
    assert results[0].discrepancy == 0
