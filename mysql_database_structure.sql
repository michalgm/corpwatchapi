-- MySQL dump 10.13  Distrib 5.5.31, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: edgarapi_live
-- ------------------------------------------------------
-- Server version	5.5.31-0ubuntu0.13.04.1-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `_croc_company_matches`
--

DROP TABLE IF EXISTS `_croc_company_matches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `_croc_company_matches` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name1` varchar(255) DEFAULT NULL,
  `name2` varchar(255) DEFAULT NULL,
  `score` decimal(5,2) DEFAULT NULL,
  `id_a` varchar(25) DEFAULT NULL,
  `id_b` varchar(25) DEFAULT NULL,
  `match_type` varchar(10) DEFAULT NULL,
  `match` int(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `id1` (`name1`),
  KEY `id2` (`name2`),
  KEY `score` (`score`)
) ENGINE=MyISAM AUTO_INCREMENT=1374 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `api_keys`
--

DROP TABLE IF EXISTS `api_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `api_keys` (
  `api_key` varchar(60) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `url` varchar(100) DEFAULT NULL,
  `intended_use` text,
  `limit` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`api_key`) USING BTREE
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `api_requests`
--

DROP TABLE IF EXISTS `api_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `api_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `api_key` varchar(60) DEFAULT NULL,
  `url` varchar(600) NOT NULL,
  `timestamp` timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(100) NOT NULL,
  `limit` int(11) NOT NULL DEFAULT '0',
  `exec_time` float unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `timestamp` (`timestamp`),
  KEY `key` (`api_key`),
  KEY `ip_address` (`ip_address`)
) ENGINE=MyISAM AUTO_INCREMENT=146428 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bad_locations`
--

DROP TABLE IF EXISTS `bad_locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bad_locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `company` varchar(300) NOT NULL,
  `location` varchar(300) NOT NULL,
  `filing_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `filing_id` (`filing_id`)
) ENGINE=MyISAM AUTO_INCREMENT=598778 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bigram_freq`
--

DROP TABLE IF EXISTS `bigram_freq`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bigram_freq` (
  `bigram` varchar(255) NOT NULL,
  `count` int(11) DEFAULT NULL,
  `weight` float DEFAULT NULL,
  PRIMARY KEY (`bigram`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cik_name_lookup`
--

DROP TABLE IF EXISTS `cik_name_lookup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cik_name_lookup` (
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `edgar_name` varchar(255) DEFAULT NULL,
  `cik` int(11) DEFAULT NULL,
  `match_name` varchar(255) DEFAULT NULL,
  `cw_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`row_id`),
  KEY `edgarid` (`cik`),
  KEY `match_name` (`match_name`),
  KEY `cw_id` (`cw_id`)
) ENGINE=MyISAM AUTO_INCREMENT=531446 DEFAULT CHARSET=utf8 COMMENT='all known names from file cik.coleft.c';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `companies`
--

DROP TABLE IF EXISTS `companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `companies` (
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `cw_id` int(11) DEFAULT NULL,
  `cik` int(11) DEFAULT NULL,
  `company_name` varchar(255) DEFAULT NULL,
  `source_type` varchar(25) DEFAULT NULL,
  `source_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`row_id`),
  KEY `cikindex` (`cik`),
  KEY `cw_id_index` (`cw_id`)
) ENGINE=MyISAM AUTO_INCREMENT=759269 DEFAULT CHARSET=utf8 COMMENT='table of entities that we treat as independent companies';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `company_filings`
--

DROP TABLE IF EXISTS `company_filings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `company_filings` (
  `filing_id` int(11) NOT NULL DEFAULT '0',
  `cik` int(11) NOT NULL,
  `year` smallint(6) NOT NULL,
  `quarter` tinyint(4) NOT NULL,
  `period_of_report` int(11) DEFAULT NULL,
  `filing_date` date NOT NULL,
  `form_10k_url` varchar(328) NOT NULL DEFAULT '',
  `sec_21_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`filing_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `company_info`
--

DROP TABLE IF EXISTS `company_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `company_info` (
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `cw_id` int(11) NOT NULL,
  `most_recent` tinyint(1) DEFAULT NULL,
  `year` int(11) NOT NULL,
  `cik` int(11) DEFAULT NULL,
  `irs_number` int(11) DEFAULT NULL,
  `best_location_id` int(11) DEFAULT NULL,
  `sic_code` int(11) DEFAULT NULL,
  `industry_name` varchar(100) DEFAULT NULL,
  `sic_sector` int(11) DEFAULT NULL,
  `sector_name` varchar(100) DEFAULT NULL,
  `source_type` varchar(25) DEFAULT NULL,
  `source_id` int(11) DEFAULT NULL,
  `num_parents` int(11) DEFAULT NULL,
  `num_children` int(11) DEFAULT NULL,
  `top_parent_id` int(11) DEFAULT NULL,
  `company_name` varchar(255) DEFAULT NULL,
  `max_year` int(11) DEFAULT NULL,
  `min_year` int(11) DEFAULT NULL,
  `no_sic` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`cw_id`,`year`) USING BTREE,
  KEY `year` (`year`),
  KEY `cik` (`cik`,`year`),
  KEY `sic_sector` (`sic_sector`),
  KEY `min_year` (`min_year`,`max_year`),
  KEY `max_year` (`max_year`,`min_year`) USING BTREE,
  KEY `irs_number` (`irs_number`),
  KEY `num_parents` (`num_parents`),
  KEY `num_children` (`num_children`),
  KEY `top_parent_id` (`top_parent_id`),
  KEY `row_id` (`row_id`),
  KEY `source_type` (`source_type`,`cw_id`) USING BTREE,
  KEY `sort` (`no_sic`,`source_type`,`company_name`,`cw_id`) USING BTREE,
  KEY `most_recent` (`most_recent`,`best_location_id`) USING BTREE,
  KEY `sic_code` (`sic_code`) USING BTREE,
  KEY `location` (`best_location_id`,`most_recent`)
) ENGINE=MyISAM AUTO_INCREMENT=2389398 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `company_locations`
--

DROP TABLE IF EXISTS `company_locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `company_locations` (
  `location_id` int(11) NOT NULL AUTO_INCREMENT,
  `cw_id` int(11) DEFAULT NULL,
  `date` date DEFAULT NULL,
  `type` varchar(15) DEFAULT NULL,
  `raw_address` varchar(500) DEFAULT NULL,
  `street_1` varchar(300) DEFAULT NULL,
  `street_2` varchar(300) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `state` varchar(40) DEFAULT NULL,
  `postal_code` varchar(11) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `country_code` char(2) DEFAULT NULL,
  `subdiv_code` char(3) DEFAULT NULL,
  `min_year` int(11) DEFAULT NULL,
  `max_year` int(11) DEFAULT NULL,
  `most_recent` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`location_id`),
  KEY `country_code` (`country_code`,`cw_id`) USING BTREE,
  KEY `subdiv_code` (`subdiv_code`,`cw_id`) USING BTREE,
  KEY `year` (`min_year`,`max_year`),
  KEY `cwindex` (`cw_id`,`min_year`,`max_year`) USING BTREE,
  KEY `most_recent` (`most_recent`),
  KEY `postal_code` (`postal_code`),
  FULLTEXT KEY `raw_address` (`raw_address`)
) ENGINE=MyISAM AUTO_INCREMENT=1202578 DEFAULT CHARSET=utf8 COMMENT='allows each company to have multiple locations associated wi';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `company_names`
--

DROP TABLE IF EXISTS `company_names`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `company_names` (
  `name_id` int(11) NOT NULL AUTO_INCREMENT,
  `cw_id` int(11) DEFAULT NULL,
  `company_name` varchar(300) DEFAULT NULL,
  `date` date DEFAULT NULL,
  `source` varchar(30) NOT NULL,
  `source_row_id` int(11) NOT NULL,
  `country_code` char(2) DEFAULT NULL,
  `subdiv_code` char(3) DEFAULT NULL,
  `min_year` int(11) DEFAULT NULL,
  `max_year` int(11) DEFAULT NULL,
  `most_recent` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`name_id`),
  KEY `country_code` (`country_code`,`subdiv_code`),
  KEY `cw_id` (`cw_id`,`company_name`,`min_year`) USING BTREE,
  KEY `year` (`min_year`,`max_year`) USING BTREE,
  KEY `most_recent` (`most_recent`),
  KEY `source` (`source`,`company_name`,`cw_id`) USING BTREE,
  KEY `sort` (`company_name`,`cw_id`),
  FULLTEXT KEY `company_name` (`company_name`)
) ENGINE=MyISAM AUTO_INCREMENT=1262374 DEFAULT CHARSET=utf8 COMMENT='This table allows for each company to have multiple name var';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `company_relations`
--

DROP TABLE IF EXISTS `company_relations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `company_relations` (
  `relation_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'not the same a s relationship_id',
  `source_cw_id` int(11) DEFAULT NULL,
  `target_cw_id` int(11) DEFAULT NULL,
  `relation_type` varchar(25) DEFAULT NULL,
  `relation_origin` varchar(25) DEFAULT NULL,
  `origin_id` int(11) DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  PRIMARY KEY (`relation_id`),
  KEY `year` (`year`),
  KEY `targer` (`target_cw_id`,`year`) USING BTREE,
  KEY `source` (`source_cw_id`,`year`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=1707871 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `country_adjectives`
--

DROP TABLE IF EXISTS `country_adjectives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `country_adjectives` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(600) DEFAULT NULL,
  `Adjective` varchar(600) DEFAULT NULL,
  `country_code` char(2) DEFAULT NULL,
  `subdiv_code` char(3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=281 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `croc_companies`
--

DROP TABLE IF EXISTS `croc_companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `croc_companies` (
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `croc_company_id` varchar(255) DEFAULT NULL,
  `croc_company_name` varchar(255) DEFAULT NULL,
  `cik` int(11) DEFAULT NULL,
  `has_sec_21` tinyint(1) DEFAULT NULL,
  `parsed_badly` tinyint(1) DEFAULT NULL,
  `cw_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`row_id`),
  KEY `companyid` (`croc_company_id`),
  KEY `companyname` (`croc_company_name`)
) ENGINE=MyISAM AUTO_INCREMENT=1281 DEFAULT CHARSET=utf8 COMMENT='dump of companies corpwatch is interested in as of 2009-1-15';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `croc_to_cwid`
--

DROP TABLE IF EXISTS `croc_to_cwid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `croc_to_cwid` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crocid` varchar(600) DEFAULT NULL,
  `name` varchar(600) DEFAULT NULL,
  `cw_id` varchar(600) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=461 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cw_id_lookup`
--

DROP TABLE IF EXISTS `cw_id_lookup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cw_id_lookup` (
  `cw_id` int(11) NOT NULL,
  `company_name` varchar(255) CHARACTER SET latin1 COLLATE latin1_general_ci NOT NULL,
  `cik` int(11) NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `country_code` char(2) CHARACTER SET latin1 NOT NULL,
  `subdiv_code` char(3) CHARACTER SET latin1 NOT NULL,
  `source` varchar(20) DEFAULT NULL,
  `orphaned` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`row_id`) USING BTREE,
  UNIQUE KEY `unique` (`cw_id`,`company_name`,`cik`,`country_code`,`subdiv_code`) USING BTREE,
  KEY `cik` (`cik`),
  KEY `orphaned` (`orphaned`),
  KEY `source` (`source`)
) ENGINE=MyISAM AUTO_INCREMENT=1264441 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `filers`
--

DROP TABLE IF EXISTS `filers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filers` (
  `filer_id` int(11) NOT NULL AUTO_INCREMENT,
  `filing_id` int(11) NOT NULL,
  `cik` int(11) DEFAULT NULL,
  `irs_number` int(11) DEFAULT NULL,
  `conformed_name` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `fiscal_year_end` smallint(6) DEFAULT NULL,
  `sic_code` int(11) DEFAULT NULL,
  `business_street_1` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `business_street_2` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `business_city` varchar(100) CHARACTER SET latin1 DEFAULT NULL,
  `business_state` varchar(40) CHARACTER SET latin1 DEFAULT NULL,
  `business_zip` varchar(11) CHARACTER SET latin1 DEFAULT NULL,
  `mail_street_1` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `mail_street_2` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `mail_city` varchar(100) CHARACTER SET latin1 DEFAULT NULL,
  `mail_state` varchar(40) CHARACTER SET latin1 DEFAULT NULL,
  `mail_zip` varchar(11) CHARACTER SET latin1 DEFAULT NULL,
  `form_type` varchar(10) CHARACTER SET latin1 DEFAULT NULL,
  `sec_act` varchar(30) CHARACTER SET latin1 DEFAULT NULL,
  `sec_file_number` varchar(30) CHARACTER SET latin1 DEFAULT NULL,
  `film_number` int(11) DEFAULT NULL,
  `former_name` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `name_change_date` varchar(15) CHARACTER SET latin1 DEFAULT NULL,
  `state_of_incorporation` varchar(40) CHARACTER SET latin1 DEFAULT NULL,
  `business_phone` varchar(30) CHARACTER SET latin1 DEFAULT NULL,
  `match_name` varchar(300) DEFAULT NULL,
  `incorp_country_code` char(2) CHARACTER SET latin1 DEFAULT NULL,
  `incorp_subdiv_code` char(3) CHARACTER SET latin1 DEFAULT NULL,
  `cw_id` int(11) DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `mail_raw_address` varchar(500) DEFAULT NULL,
  `business_raw_address` varchar(500) DEFAULT NULL,
  `bad_cik` tinyint(1) DEFAULT '0',
  `sec_21` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`filer_id`),
  KEY `cik` (`cik`,`year`) USING BTREE,
  KEY `cw_id` (`cw_id`,`year`) USING BTREE,
  KEY `clean_name` (`match_name`,`year`,`cik`) USING BTREE,
  KEY `business_street` (`business_street_1`(1)),
  KEY `mail_street` (`mail_street_1`(1)),
  KEY `filing_id` (`filing_id`),
  KEY `year` (`year`),
  KEY `sec_21` (`sec_21`)
) ENGINE=MyISAM AUTO_INCREMENT=897026 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `filing_tables`
--

DROP TABLE IF EXISTS `filing_tables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filing_tables` (
  `filing_table_id` int(11) NOT NULL AUTO_INCREMENT,
  `filing_id` int(11) NOT NULL DEFAULT '0',
  `table_num` int(11) NOT NULL DEFAULT '0',
  `num_rows` int(11) NOT NULL DEFAULT '0',
  `num_cols` int(11) NOT NULL DEFAULT '0',
  `headers` varchar(600) CHARACTER SET latin1 NOT NULL DEFAULT '0',
  `parsed` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`filing_table_id`),
  KEY `filing_id` (`filing_id`),
  KEY `table_num` (`table_num`)
) ENGINE=MyISAM AUTO_INCREMENT=81242 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `filings`
--

DROP TABLE IF EXISTS `filings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filings` (
  `filing_id` int(11) NOT NULL AUTO_INCREMENT,
  `filing_date` date NOT NULL,
  `type` varchar(36) NOT NULL,
  `company_name` varchar(300) DEFAULT NULL,
  `filename` varchar(300) NOT NULL,
  `cik` int(11) NOT NULL,
  `has_sec21` tinyint(1) NOT NULL DEFAULT '0',
  `year` smallint(6) NOT NULL,
  `quarter` tinyint(1) DEFAULT NULL,
  `has_html` tinyint(1) NOT NULL DEFAULT '0',
  `num_tables` int(11) NOT NULL DEFAULT '0',
  `num_rows` int(11) NOT NULL DEFAULT '0',
  `tables_parsed` int(11) NOT NULL DEFAULT '0',
  `rows_parsed` int(11) NOT NULL DEFAULT '0',
  `period_of_report` int(11) DEFAULT NULL,
  `date_filed` int(11) DEFAULT NULL,
  `date_changed` int(11) DEFAULT NULL,
  `sec_21_url` varchar(255) DEFAULT NULL,
  `bad_header` tinyint(1) DEFAULT '0',
  `bad_sec21` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`filing_id`),
  KEY `has_sec21` (`has_sec21`),
  KEY `type` (`type`),
  KEY `cik` (`cik`,`year`,`filing_id`) USING BTREE,
  KEY `bad_header` (`bad_header`),
  KEY `year` (`year`,`quarter`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=11024715 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `filings_lookup`
--

DROP TABLE IF EXISTS `filings_lookup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filings_lookup` (
  `cw_id` int(11) NOT NULL DEFAULT '0',
  `filing_id` int(11) NOT NULL,
  `company_is_filer` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`cw_id`,`filing_id`) USING BTREE
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `fortune1000`
--

DROP TABLE IF EXISTS `fortune1000`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fortune1000` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `Rank` varchar(600) DEFAULT NULL,
  `Name` varchar(600) DEFAULT NULL,
  `Revenue` varchar(600) DEFAULT NULL,
  `Profit` varchar(600) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1001 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `meta`
--

DROP TABLE IF EXISTS `meta`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta` (
  `meta` varchar(40) NOT NULL,
  `value` varchar(200) NOT NULL,
  PRIMARY KEY (`meta`) USING BTREE
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `no_relationship_filings`
--

DROP TABLE IF EXISTS `no_relationship_filings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `no_relationship_filings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `filing_id` varchar(600) DEFAULT NULL,
  `cik` varchar(600) DEFAULT NULL,
  `company_name` varchar(600) DEFAULT NULL,
  `code` varchar(600) DEFAULT NULL,
  `blank` varchar(600) DEFAULT NULL,
  `1___none` varchar(600) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=420 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `not_company_names`
--

DROP TABLE IF EXISTS `not_company_names`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `not_company_names` (
  `name` varchar(250) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `parsing_stop_terms`
--

DROP TABLE IF EXISTS `parsing_stop_terms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `parsing_stop_terms` (
  `term` varchar(250) NOT NULL,
  PRIMARY KEY (`term`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `parsing_tests`
--

DROP TABLE IF EXISTS `parsing_tests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `parsing_tests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cik` varchar(600) DEFAULT NULL,
  `has_hierarchy` varchar(600) DEFAULT NULL,
  `has_multiple_values` varchar(600) DEFAULT NULL,
  `has_percentage` varchar(600) DEFAULT NULL,
  `notes` varchar(600) DEFAULT NULL,
  `assumed_name` varchar(600) DEFAULT NULL,
  `original_companies` int(11) NOT NULL,
  `matched_companies` int(11) NOT NULL,
  `orphaned_original_companies` int(11) NOT NULL,
  `orphaned_relationship_companies` int(11) NOT NULL,
  `orphaned_original_companies_no_location` int(11) NOT NULL,
  `relationship_companies` int(11) NOT NULL,
  `mismatched_locations` int(11) NOT NULL,
  `filing_id` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=27 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `region_codes`
--

DROP TABLE IF EXISTS `region_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `region_codes` (
  `code` char(2) NOT NULL DEFAULT '',
  `region_name` varchar(100) DEFAULT NULL,
  `type` varchar(25) DEFAULT NULL,
  `country_code` char(2) DEFAULT NULL,
  `subdiv_code` char(3) DEFAULT NULL,
  PRIMARY KEY (`code`),
  KEY `regionname` (`region_name`),
  KEY `contrycode` (`country_code`),
  KEY `subdiv` (`subdiv_code`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='country and state codes as used in the edgar db';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `relationships`
--

DROP TABLE IF EXISTS `relationships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `relationships` (
  `relationship_id` int(11) NOT NULL AUTO_INCREMENT,
  `company_name` varchar(300) DEFAULT NULL,
  `location` varchar(200) NOT NULL,
  `filing_id` int(11) NOT NULL,
  `country_code` char(2) CHARACTER SET latin1 DEFAULT NULL,
  `subdiv_code` char(3) CHARACTER SET latin1 DEFAULT NULL,
  `clean_company` varchar(300) DEFAULT NULL,
  `cik` int(11) DEFAULT NULL,
  `ignore_record` tinyint(1) DEFAULT '0',
  `parse_method` varchar(100) DEFAULT NULL,
  `hierarchy` int(11) DEFAULT '0',
  `percent` int(11) DEFAULT NULL,
  `parent_cw_id` int(11) DEFAULT NULL,
  `cw_id` int(11) DEFAULT NULL,
  `filer_cik` int(11) DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `quarter` int(11) DEFAULT NULL,
  PRIMARY KEY (`relationship_id`),
  KEY `filing_id` (`filing_id`),
  KEY `filer_cik` (`filer_cik`,`year`) USING BTREE,
  KEY `cw_id` (`cw_id`,`parent_cw_id`) USING BTREE,
  KEY `cik` (`cik`,`year`) USING BTREE,
  KEY `clean_company` (`clean_company`,`year`,`filer_cik`) USING BTREE,
  KEY `parent_cw_id` (`parent_cw_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3012481 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sic_codes`
--

DROP TABLE IF EXISTS `sic_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sic_codes` (
  `sic_code` char(4) NOT NULL,
  `industry_name` varchar(100) DEFAULT NULL,
  `sic_sector` char(4) DEFAULT NULL,
  PRIMARY KEY (`sic_code`),
  KEY `sic_sector` (`sic_sector`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sic_sectors`
--

DROP TABLE IF EXISTS `sic_sectors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sic_sectors` (
  `sic_sector` char(4) NOT NULL,
  `sector_name` varchar(100) DEFAULT NULL,
  `sector_group` int(11) DEFAULT NULL,
  `sector_group_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`sic_sector`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stock_codes`
--

DROP TABLE IF EXISTS `stock_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stock_codes` (
  `stock_name` varchar(255) DEFAULT NULL,
  `ticker_code` char(5) NOT NULL,
  `exchange` char(6) DEFAULT NULL,
  `cw_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`ticker_code`),
  KEY `name` (`stock_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='comp nams and tick symbol from google';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `strip_company_strings`
--

DROP TABLE IF EXISTS `strip_company_strings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `strip_company_strings` (
  `string` varchar(300) NOT NULL,
  PRIMARY KEY (`string`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `un_countries`
--

DROP TABLE IF EXISTS `un_countries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `un_countries` (
  `country_code` char(2) NOT NULL,
  `country_name` varchar(255) DEFAULT NULL,
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  PRIMARY KEY (`row_id`),
  KEY `countrycode` (`country_code`),
  KEY `countryname` (`country_name`)
) ENGINE=MyISAM AUTO_INCREMENT=245 DEFAULT CHARSET=utf8 COMMENT='countries from unlocode standard';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `un_country_aliases`
--

DROP TABLE IF EXISTS `un_country_aliases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `un_country_aliases` (
  `country_code` char(2) DEFAULT NULL,
  `country_name` varchar(255) NOT NULL DEFAULT '',
  `subdiv_code` char(3) DEFAULT NULL,
  PRIMARY KEY (`country_name`),
  KEY `countrycode` (`country_code`),
  KEY `country_name` (`country_name`),
  KEY `subdivcode` (`subdiv_code`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='alternate wordings of country names';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `un_country_subdivisions`
--

DROP TABLE IF EXISTS `un_country_subdivisions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `un_country_subdivisions` (
  `country_code` char(2) DEFAULT NULL,
  `subdivision_code` char(3) DEFAULT NULL,
  `subdivision_name` varchar(255) DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `row_id` int(11) NOT NULL AUTO_INCREMENT,
  `dupe` tinyint(1) NOT NULL DEFAULT '0',
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  PRIMARY KEY (`row_id`),
  KEY `countycode` (`country_code`),
  KEY `subdiv` (`subdivision_code`),
  KEY `subdivname` (`subdivision_name`)
) ENGINE=MyISAM AUTO_INCREMENT=968 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `unlocode`
--

DROP TABLE IF EXISTS `unlocode`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `unlocode` (
  `loc_id` int(11) NOT NULL AUTO_INCREMENT,
  `country_code` char(2) NOT NULL,
  `loc_code` char(3) DEFAULT NULL,
  `location_name_diacrit` varchar(255) DEFAULT NULL,
  `location_name` varchar(255) DEFAULT NULL,
  `subdivision_code` char(3) DEFAULT NULL,
  `function` char(8) DEFAULT NULL,
  `status` char(2) DEFAULT NULL,
  `date` char(4) DEFAULT NULL,
  `iata_code` char(3) DEFAULT NULL,
  `coordinates` char(15) DEFAULT NULL,
  `remarks` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`loc_id`),
  KEY `locname` (`location_name`),
  KEY `locnamedi` (`location_name_diacrit`),
  KEY `loccode` (`loc_code`),
  KEY `country` (`country_code`)
) ENGINE=MyISAM AUTO_INCREMENT=57093 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `word_freq`
--

DROP TABLE IF EXISTS `word_freq`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `word_freq` (
  `word` varchar(255) NOT NULL,
  `count` int(11) DEFAULT NULL,
  `weight` float DEFAULT NULL,
  PRIMARY KEY (`word`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='counts of word occurences in the list of edgar entity names';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-05-30  9:43:47
