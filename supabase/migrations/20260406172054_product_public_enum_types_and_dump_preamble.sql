-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:20:54Z

SET check_function_bodies = false;

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

--
-- Name: account_deletion_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.account_deletion_status AS ENUM (
    'requested',
    'approved',
    'processing',
    'completed',
    'failed',
    'cancelled'
);

--
-- Name: app_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.app_role AS ENUM (
    'psychologist',
    'patient',
    'assistant',
    'admin'
);

--
-- Name: block_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.block_type AS ENUM (
    'lunch',
    'break',
    'vacation',
    'personal',
    'unavailable'
);

--
-- Name: business_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.business_type AS ENUM (
    'PF',
    'PJ'
);

--
-- Name: calendar_event_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.calendar_event_source AS ENUM (
    'fluri',
    'google'
);

--
-- Name: calendar_event_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.calendar_event_status AS ENUM (
    'scheduled',
    'confirmed',
    'in_progress',
    'completed',
    'cancelled',
    'no_show',
    'rescheduled'
);

--
-- Name: calendar_event_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.calendar_event_type AS ENUM (
    'session',
    'supervision',
    'meeting',
    'task',
    'block',
    'other'
);

--
-- Name: calendar_event_type_new; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.calendar_event_type_new AS ENUM (
    'session',
    'supervision',
    'meeting',
    'block',
    'other'
);

--
-- Name: cancellation_policy_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.cancellation_policy_code AS ENUM (
    'flexible',
    'standard',
    'strict',
    'non_refundable'
);

--
-- Name: clinical_note_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.clinical_note_type AS ENUM (
    'clinical_note',
    'progress_note'
);

--
-- Name: TYPE clinical_note_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.clinical_note_type IS 'Psychologist note types: clinical_note (standalone) or progress_note (may chain via parent_note_id)';

--
-- Name: clinical_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.clinical_scope AS ENUM (
    'therapy',
    'assessment',
    'intervention',
    'psychoeducation',
    'report',
    'supervision'
);

--
-- Name: clinical_session_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.clinical_session_status AS ENUM (
    'scheduled',
    'completed',
    'cancelled',
    'no_show',
    'open'
);

--
-- Name: clinical_session_status_new; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.clinical_session_status_new AS ENUM (
    'scheduled',
    'open',
    'completed',
    'cancelled',
    'no_show'
);

--
-- Name: contact_method_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contact_method_type AS ENUM (
    'whatsapp',
    'sms',
    'email',
    'phone'
);

--
-- Name: delivery_mode; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.delivery_mode AS ENUM (
    'in_person',
    'telehealth',
    'hybrid'
);

--
-- Name: financial_entry_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.financial_entry_status AS ENUM (
    'confirmed',
    'pending',
    'cancelled'
);

--
-- Name: google_sync_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.google_sync_status AS ENUM (
    'pending',
    'synced',
    'error',
    'not_synced'
);

--
-- Name: interview_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.interview_kind AS ENUM (
    'structured',
    'semi_structured',
    'unstructured'
);

--
-- Name: invite_status_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.invite_status_type AS ENUM (
    'pending',
    'accepted',
    'expired',
    'cancelled'
);

--
-- Name: marketplace_payment_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.marketplace_payment_status AS ENUM (
    'requires_payment_method',
    'requires_action',
    'processing',
    'succeeded',
    'canceled',
    'refunded',
    'failed'
);

--
-- Name: medical_item_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.medical_item_kind AS ENUM (
    'mental_disorder',
    'chronic_disease',
    'physical_disability',
    'other',
    'medication_intake'
);

--
-- Name: modality; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.modality AS ENUM (
    'individual',
    'couple',
    'family',
    'group'
);

--
-- Name: onboarding_module; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.onboarding_module AS ENUM (
    'professional_registration',
    'identity_verification',
    'practice_configuration'
);

--
-- Name: patient_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.patient_status AS ENUM (
    'active',
    'inactive',
    'on_break',
    'discharged'
);

--
-- Name: payment_method_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_method_type AS ENUM (
    'fluripay',
    'card',
    'cash',
    'pix',
    'bank_transfer',
    'other'
);

--
-- Name: payment_status_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_status_type AS ENUM (
    'pending',
    'paid',
    'overdue',
    'refunded',
    'cancelled'
);

--
-- Name: population; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.population AS ENUM (
    'child',
    'adolescent',
    'adult',
    'older_adult'
);

--
-- Name: practice_modality; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.practice_modality AS ENUM (
    'in_person',
    'online',
    'hybrid'
);
