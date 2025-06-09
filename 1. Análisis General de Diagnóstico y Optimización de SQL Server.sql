USE [NombreDeTuBaseDeDatos]; -- Reemplaza con el nombre de tu base

-- 1. Informacion general del sistema
PRINT '--- Información General del Sistema ---';
SELECT 
    SERVERPROPERTY('MachineName') AS [Servidor],
    SERVERPROPERTY('Edition') AS [Edición],
    SERVERPROPERTY('ProductVersion') AS [Versión],
    SERVERPROPERTY('EngineEdition') AS [TipoMotor],
    sysdatetime() AS [FechaHoraActual];

-- 2. Top esperas
PRINT '--- Top 10 Tipos de Espera (en segundos) ---';
SELECT TOP 10 
    wait_type, 
    wait_time_ms / 1000.0 AS wait_time_sec, 
    waiting_tasks_count,
    (wait_time_ms * 1.0 / waiting_tasks_count) / 1000.0 AS avg_wait_sec
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK','SLEEP_SYSTEMTASK',
    'SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE','CHECKPOINT_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
    'CLR_MANUAL_EVENT','CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE',
    'FT_IFTS_SCHEDULER_IDLE_WAIT','XE_DISPATCHER_WAIT','XE_DISPATCHER_JOIN',
    'SQLTRACE_INCREMENTAL_FLUSH_SLEEP'
)
ORDER BY wait_time_sec DESC;


-- 3. Consultas más costosas
PRINT '--- Top 10 Consultas Más Costosas (promedio por ejecución) ---';
SELECT TOP 10
    qs.execution_count,
    qs.total_worker_time / qs.execution_count AS avg_cpu,
    qs.total_elapsed_time / qs.execution_count AS avg_time,
    qs.total_logical_reads / qs.execution_count AS avg_reads,
    st.text AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY avg_time DESC;

-- 4. Fragmentación de índices
PRINT '--- Índices Fragmentados (>20%) ---';
SELECT 
    OBJECT_NAME(ps.object_id) AS TableName,
    i.name AS IndexName,
    ps.index_id,
    ps.avg_fragmentation_in_percent,
    ps.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i 
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.database_id = DB_ID()
  AND ps.avg_fragmentation_in_percent > 20
  AND ps.page_count > 100
ORDER BY ps.avg_fragmentation_in_percent DESC;

-- 5. Estadísticas de uso de índices
PRINT '--- Índices No Usados (Lecturas = 0) ---';
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.index_id,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates
FROM sys.indexes AS i
LEFT JOIN sys.dm_db_index_usage_stats AS s 
    ON i.object_id = s.object_id AND i.index_id = s.index_id AND s.database_id = DB_ID()
WHERE i.type_desc = 'NONCLUSTERED'
  AND ISNULL(s.user_seeks, 0) = 0
  AND ISNULL(s.user_scans, 0) = 0
  AND ISNULL(s.user_lookups, 0) = 0
ORDER BY i.object_id;

-- 6. Sugerencias de índices faltantes
PRINT '--- Sugerencias de Índices Faltantes ---';
SELECT TOP 10
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS ImpactoEstimado,
    mid.statement AS Tabla,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
ORDER BY ImpactoEstimado DESC;

-- 7. Últimas estadísticas de actualización
PRINT '--- Últimas Estadísticas de Actualización ---';
SELECT 
    o.name AS TableName,
    s.name AS StatisticName,
    STATS_DATE(s.object_id, s.stats_id) AS LastUpdated
FROM sys.stats s
JOIN sys.objects o ON s.object_id = o.object_id
WHERE o.type = 'U'
ORDER BY LastUpdated ASC;
