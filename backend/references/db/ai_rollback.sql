-- =====================================================
-- AI 层整体回滚：删除 ai schema 及其全部对象（含装入其中的 pg_trgm 扩展）。
--
-- 只影响 AI 派生数据，gallery / user_data / comix 的原始数据与媒体文件
-- 不受任何影响；重新执行 ai.sql 即可从零重建（队列会由 reconcile 自动补回）。
-- =====================================================

\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS ai CASCADE;
