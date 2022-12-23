﻿CREATE FUNCTION sys_PhysicalIndexStatistics_Wrapper
 (
         @DatabaseID INT,
         @ObjectID INT,
         @IndexID INT,
         @PartitionNumber INT,
         @Mode INT
 )
 RETURNS @IndexStats TABLE
 (
         DatabaseID SMALLINT,
         ObjectID INT,
         IndexID INT,
         PartitionNumber INT,
         IndexDescription VARCHAR(100),
         AllocationTypeDescription VARCHAR(100),
         IndexDepth TINYINT,
         IndexLevel TINYINT,
         AverageFragmentation FLOAT,
         FragmentCount BIGINT,
         AverageFragmentSize FLOAT,
         TablePageCount BIGINT,
         AveragePageSpaceUsed FLOAT,
         RecordCount BIGINT,
         GhostRecordCount BIGINT,
         VersionGhostRecordCount BIGINT,
         MinimumRecordSize INT,
         MaxRecordSize INT,
         AverageRecordSize FLOAT,
         ForwardedRecordCount BIGINT
 )
 BEGIN     INSERT INTO @IndexStats
         (
             DatabaseID, ObjectID, IndexID, PartitionNumber, IndexDescription, AllocationTypeDescription, IndexDepth,
             IndexLevel, AverageFragmentation, FragmentCount, AverageFragmentSize, TablePageCount,
             AveragePageSpaceUsed, RecordCount, GhostRecordCount, VersionGhostRecordCount, MinimumRecordSize,
             MaxRecordSize, AverageRecordSize, ForwardedRecordCount
         )
     SELECT
             database_id, object_id, index_id, partition_number, index_type_desc,
             alloc_unit_type_desc, index_depth,
             index_level, avg_fragmentation_in_percent, fragment_count, avg_fragment_size_in_pages, page_count,
             avg_page_space_used_in_percent, record_count, ghost_record_count, version_ghost_record_count, min_record_size_in_bytes,
             max_record_size_in_bytes, avg_record_size_in_bytes, forwarded_record_count
        FROM
                 sys.dm_db_index_physical_stats
              (
                        @DatabaseID,
                        @ObjectID,
                   @IndexID,
                   @PartitionNumber,
                   @Mode
              )
     RETURN
END