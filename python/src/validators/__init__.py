"""
Data Validators Module
Provides utilities for validating data migration between source and target databases
"""

import logging
from typing import Dict, Any, List, Optional
import psycopg2
import redshift_connector
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class ValidationResult:
    """Data class for validation results"""
    table_name: str
    source_count: int
    target_count: int
    is_valid: bool
    discrepancy: int
    message: str


class DataValidator:
    """Validator for comparing source and target database data"""

    def __init__(
        self,
        source_config: Dict[str, Any],
        target_config: Dict[str, Any]
    ):
        """
        Initialize Data Validator
        
        Args:
            source_config: Source database configuration
            target_config: Target database configuration
        """
        self.source_config = source_config
        self.target_config = target_config
        self.source_conn = None
        self.target_conn = None

    def connect_source(self) -> None:
        """Connect to source PostgreSQL database"""
        try:
            self.source_conn = psycopg2.connect(
                host=self.source_config['host'],
                port=self.source_config.get('port', 5432),
                database=self.source_config['database'],
                user=self.source_config['username'],
                password=self.source_config['password']
            )
            logger.info("Connected to source database")
        except Exception as e:
            logger.error(f"Error connecting to source database: {e}")
            raise

    def connect_target(self) -> None:
        """Connect to target Redshift database"""
        try:
            self.target_conn = redshift_connector.connect(
                host=self.target_config['host'],
                port=self.target_config.get('port', 5439),
                database=self.target_config['database'],
                user=self.target_config['username'],
                password=self.target_config['password']
            )
            logger.info("Connected to target database")
        except Exception as e:
            logger.error(f"Error connecting to target database: {e}")
            raise

    def disconnect(self) -> None:
        """Close database connections"""
        if self.source_conn:
            self.source_conn.close()
            logger.info("Disconnected from source database")
        if self.target_conn:
            self.target_conn.close()
            logger.info("Disconnected from target database")

    def get_row_count(
        self,
        connection: Any,
        schema: str,
        table: str
    ) -> int:
        """
        Get row count for a table
        
        Args:
            connection: Database connection
            schema: Schema name
            table: Table name
            
        Returns:
            Row count
        """
        try:
            cursor = connection.cursor()
            query = f"SELECT COUNT(*) FROM {schema}.{table}"
            cursor.execute(query)
            count = cursor.fetchone()[0]
            cursor.close()
            return count
        except Exception as e:
            logger.error(f"Error getting row count for {schema}.{table}: {e}")
            raise

    def validate_row_counts(
        self,
        tables: List[Dict[str, str]],
        tolerance: int = 0
    ) -> List[ValidationResult]:
        """
        Validate row counts between source and target
        
        Args:
            tables: List of tables to validate (schema and table name)
            tolerance: Acceptable difference in row counts
            
        Returns:
            List of validation results
        """
        self.connect_source()
        self.connect_target()
        
        results = []
        
        try:
            for table_info in tables:
                schema = table_info.get('schema', 'public')
                table = table_info['table']
                
                source_count = self.get_row_count(
                    self.source_conn,
                    schema,
                    table
                )
                target_count = self.get_row_count(
                    self.target_conn,
                    schema,
                    table
                )
                
                discrepancy = abs(source_count - target_count)
                is_valid = discrepancy <= tolerance
                
                message = "Valid" if is_valid else f"Discrepancy: {discrepancy} rows"
                
                result = ValidationResult(
                    table_name=f"{schema}.{table}",
                    source_count=source_count,
                    target_count=target_count,
                    is_valid=is_valid,
                    discrepancy=discrepancy,
                    message=message
                )
                
                results.append(result)
                logger.info(
                    f"Validation for {schema}.{table}: "
                    f"Source={source_count}, Target={target_count}, {message}"
                )
                
        finally:
            self.disconnect()
            
        return results

    def validate_checksums(
        self,
        schema: str,
        table: str,
        sample_size: Optional[int] = None
    ) -> bool:
        """
        Validate data using checksums
        
        Args:
            schema: Schema name
            table: Table name
            sample_size: Number of rows to sample (None for all)
            
        Returns:
            True if checksums match, False otherwise
        """
        self.connect_source()
        self.connect_target()
        
        try:
            # Get primary key columns
            source_cursor = self.source_conn.cursor()
            pk_query = f"""
                SELECT a.attname
                FROM pg_index i
                JOIN pg_attribute a ON a.attrelid = i.indrelid
                    AND a.attnum = ANY(i.indkey)
                WHERE i.indrelid = '{schema}.{table}'::regclass
                    AND i.indisprimary
            """
            source_cursor.execute(pk_query)
            pk_columns = [row[0] for row in source_cursor.fetchall()]
            
            if not pk_columns:
                logger.warning(f"No primary key found for {schema}.{table}")
                return False
                
            # Build checksum query
            limit_clause = f"LIMIT {sample_size}" if sample_size else ""
            checksum_query = f"""
                SELECT MD5(CAST(ROW({', '.join(pk_columns)}) AS TEXT))
                FROM {schema}.{table}
                ORDER BY {', '.join(pk_columns)}
                {limit_clause}
            """
            
            source_cursor.execute(checksum_query)
            source_checksums = set(row[0] for row in source_cursor.fetchall())
            
            target_cursor = self.target_conn.cursor()
            target_cursor.execute(checksum_query)
            target_checksums = set(row[0] for row in target_cursor.fetchall())
            
            source_cursor.close()
            target_cursor.close()
            
            is_valid = source_checksums == target_checksums
            
            if not is_valid:
                missing_in_target = len(source_checksums - target_checksums)
                missing_in_source = len(target_checksums - source_checksums)
                logger.warning(
                    f"Checksum validation failed for {schema}.{table}: "
                    f"{missing_in_target} rows missing in target, "
                    f"{missing_in_source} extra rows in target"
                )
            else:
                logger.info(f"Checksum validation passed for {schema}.{table}")
                
            return is_valid
            
        except Exception as e:
            logger.error(f"Error validating checksums: {e}")
            raise
        finally:
            self.disconnect()

    def get_column_statistics(
        self,
        schema: str,
        table: str
    ) -> Dict[str, Dict[str, Any]]:
        """
        Get column statistics for comparison
        
        Args:
            schema: Schema name
            table: Table name
            
        Returns:
            Dictionary of column statistics
        """
        stats = {'source': {}, 'target': {}}
        
        self.connect_source()
        self.connect_target()
        
        try:
            # Get numeric columns
            source_cursor = self.source_conn.cursor()
            columns_query = f"""
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_schema = '{schema}'
                    AND table_name = '{table}'
                    AND data_type IN ('integer', 'bigint', 'numeric', 'real', 'double precision')
            """
            source_cursor.execute(columns_query)
            numeric_columns = source_cursor.fetchall()
            
            for col_name, col_type in numeric_columns:
                # Source statistics
                source_cursor.execute(
                    f"SELECT MIN({col_name}), MAX({col_name}), AVG({col_name}) "
                    f"FROM {schema}.{table}"
                )
                source_stats = source_cursor.fetchone()
                stats['source'][col_name] = {
                    'min': source_stats[0],
                    'max': source_stats[1],
                    'avg': source_stats[2]
                }
                
                # Target statistics
                target_cursor = self.target_conn.cursor()
                target_cursor.execute(
                    f"SELECT MIN({col_name}), MAX({col_name}), AVG({col_name}) "
                    f"FROM {schema}.{table}"
                )
                target_stats = target_cursor.fetchone()
                stats['target'][col_name] = {
                    'min': target_stats[0],
                    'max': target_stats[1],
                    'avg': target_stats[2]
                }
                target_cursor.close()
                
            source_cursor.close()
            
        except Exception as e:
            logger.error(f"Error getting column statistics: {e}")
            raise
        finally:
            self.disconnect()
            
        return stats
