USE [NOME_DO_BANCO]
GO

IF EXISTS (SELECT 1
           FROM   SYS.OBJECTS
           WHERE  OBJECT_ID = OBJECT_ID('dbo.NOME_DA_PROCEDURE')
                  AND TYPE IN ('P', 'PC'))
  DROP PROCEDURE [dbo].[NOME_DA_PROCEDURE]

GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[NOME_DA_PROCEDURE]
(
	@codigo_um INT,
	@codigo_dois INT,
	@DETALHES XML,
	@usuario VARCHAR (20),
	@data DATETIME
)
AS
BEGIN

	DECLARE @rowcounts TABLE
	(
		mergeAction nvarchar(10)
	);
	
	DECLARE @insertCount INT = 0,
	        @deleteCount INT = 0,
			@updateCount INT = 0

	SET NOCOUNT ON

	SELECT
		t.value('CodigoDetalhe[1]','INT') AS codigo_detalhe,
		t.value('InformacaoUm[1]', 'VARCHAR(50)') AS informacao_um,
		t.value('InformacaoDois[1]', 'VARCHAR(50)') AS informacao_dois,
		t.value('InformacaoTres[1]', 'VARCHAR(50)') AS informacao_tres,
		t.value('IsAssociado[1]','BIT') AS is_associado
	INTO #TMP_DETALHES
	FROM @DETALHES.nodes('/Detalhes/Detalhe') AS TempTable(t)

	-- REALIZA O JOIN DA TABELA TEMPORÁRIA COM A TABELA DO BANCO PELAS CHAVES
	MERGE TB_DESTINO_DO_BANCO AS Destino

	USING #TMP_DETALHES AS Origem

	ON (Destino.codigo_um = @codigo_um
	    AND Destino.codigo_dois = @codigo_dois
	    AND Destino.codigo_detalhe = Origem.codigo_detalhe)

	
	-- DELETA
	WHEN MATCHED AND Origem.is_associado = 0 THEN
		DELETE
	
	
	-- ATUALIZA
	WHEN MATCHED AND (Origem.is_associado = 1 AND
	                  (Destino.informacao_um <> Origem.informacao_um OR
	                   Destino.informacao_dois <> Origem.informacao_dois OR
					   Destino.informacao_tres <> Origem.informacao_tres)) THEN
					  
		UPDATE SET
			Destino.informacao_um = Origem.informacao_um,
	        Destino.informacao_dois = Origem.informacao_dois,
			Destino.informacao_tres = Origem.informacao_tres
	
		
	-- INSERE
	WHEN NOT MATCHED AND Origem.is_associado = 1 THEN
		INSERT
		(
	        codigo_um,
			codigo_dois,
			codigo_detalhe,
			informacao_um,
			informacao_dois,
			informacao_tres,
			usuario,
			data
		)
		VALUES
        (
			@codigo_um,
			@codigo_dois,
			Origem.codigo_detalhe,
			Origem.informacao_um,
			Origem.informacao_dois,
			Origem.informacao_tres,
			@usuario,
			@data
		)  

	OUTPUT $action into @rowcounts;

	SELECT    
		@insertcount=[INSERT],
		@updatecount=[UPDATE],
        @deletecount=[DELETE]
	FROM (SELECT mergeAction, 1 ROWS FROM @rowcounts)p
	PIVOT(COUNT(ROWS) FOR mergeAction IN ( [INSERT], [UPDATE], [DELETE])) AS pvt;

	SELECT CASE WHEN (@insertcount + @updatecount + @deletecount) = 0
		THEN 0
		ELSE 1
	END HOUVE_ALTERACAO	

END

GO

GRANT EXEC ON [dbo].[NOME_DA_PROCEDURE] TO PUBLIC

GO