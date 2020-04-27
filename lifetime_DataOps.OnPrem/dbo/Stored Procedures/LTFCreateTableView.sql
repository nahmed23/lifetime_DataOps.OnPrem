

CREATE PROCEDURE [dbo].[LTFCreateTableView]
  @TableName VARCHAR(100), -- The Table for which a view need to be created
  @ViewDB   VARCHAR(100)   --database name where the table exist

AS
BEGIN

  DECLARE @ColumnName VARCHAR(100)
  DECLARE @Stmt       nVARCHAR(4000)
  DECLARE @Stmt2      VARCHAR(2000)

--View does not currently exist
IF(select COUNT(*) from dbo.sysobjects where  OBJECTPROPERTY(id, N'IsView') = 1 and name like 'v' + @TableName) = 0
begin
  SET @Stmt = '--THIS IS AN AUTO GENERATED VIEW'+ char(10)
  SET @Stmt = @Stmt + 'if exists (select * ' +
                                   'from dbo.sysobjects ' +
                                  'where id = object_id(N''[dbo].[v' + @TableName + ']'') ' +
                                    'and OBJECTPROPERTY(id, N''IsView'') = 1)' + char(10)
  SET @Stmt = @Stmt + 'drop view [dbo].[v' + @TableName + ']' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'SET QUOTED_IDENTIFIER ON' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'SET ANSI_NULLS ON' + char(10)
  EXEC (@Stmt)

  SET @Stmt = 'CREATE VIEW dbo.v' + @TableName + ' AS '  + char(10) + 'SELECT '
end
else
--View does exist
begin

  SET @Stmt = 'SET QUOTED_IDENTIFIER ON' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'SET ANSI_NULLS ON' + char(10)
  EXEC (@Stmt)

  SET @Stmt = 'ALTER VIEW dbo.v' + @TableName + ' AS '  + char(10) + 'SELECT '
end

  SET @Stmt2 = 'DECLARE curColumnName CURSOR GLOBAL FOR ' +
               ' SELECT COLUMN_NAME ColumnName ' +
               ' FROM ' + @ViewDB + '.INFORMATION_SCHEMA.COLUMNS ' +
               ' WHERE TABLE_SCHEMA = ''dbo'' ' +
               '   AND TABLE_NAME = ''' + @TableName + ''' ' +
               ' ORDER ' +
               '    BY ORDINAL_POSITION'
  EXEC (@Stmt2)

  OPEN curColumnName

  FETCH NEXT
  FROM curColumnName
  INTO @ColumnName

  WHILE @@FETCH_STATUS = 0
  BEGIN
--    IF @ColumnName <> 'InsertedDateTime' AND @ColumnName <> 'UpdatedDateTime'
--    BEGIN
      SET @Stmt = @Stmt + @ColumnName
--    END

    FETCH NEXT
    FROM curColumnName
    INTO @ColumnName

    IF @@FETCH_STATUS = 0
--      IF @ColumnName <> 'InsertedDateTime' AND @ColumnName <> 'UpdatedDateTime'
--      BEGIN
        SET @Stmt = @Stmt + ','
--      END
  END

  CLOSE curColumnName
  DEALLOCATE curColumnName

  SET @Stmt = @Stmt + char(10) + 'FROM ' + @ViewDB + '.dbo.' + @TableName
                    + ' WITH(NOLOCK)' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'SET QUOTED_IDENTIFIER OFF' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'SET ANSI_NULLS ON' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'GRANT  SELECT  ON [dbo].[v'
  SET @Stmt = @Stmt + @TableName + ']  TO [Brio_Report]' + char(10)
  EXEC (@Stmt)
  SET @Stmt = 'GRANT  SELECT  ON [dbo].[v'
  SET @Stmt = @Stmt + @TableName + ']  TO [MMSPoolUser]' + char(10)
  EXEC (@Stmt)

  SET @Stmt = ''

END
