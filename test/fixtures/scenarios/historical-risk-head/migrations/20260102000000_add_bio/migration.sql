SET lock_timeout = '2s';
SET statement_timeout = '5min';
SET application_name = 'migrate:add_bio';
SET idle_in_transaction_session_timeout = '30s';

ALTER TABLE "User" ADD COLUMN "bio" TEXT;
