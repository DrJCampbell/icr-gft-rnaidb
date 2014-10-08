-- MySQL Script generated by MySQL Workbench
-- Thu Jul 31 16:03:43 2014
-- Model: New Model    Version: 1.0
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema RNAi_analysis_database
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `RNAi_analysis_database` DEFAULT CHARACTER SET utf8 ;
USE `RNAi_analysis_database` ;

-- --------------------------------------------------------
-- Table `RNAi_analysis_database`.`Name_of_set_if_isogenic`
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Name_of_set_if_isogenic` (
  `Name_of_set_if_isogenic_ID` INT NOT NULL AUTO_INCREMENT,
  `Name_of_set_if_isogenic` VARCHAR(45) NULL,
  PRIMARY KEY (`Name_of_set_if_isogenic_ID`))
ENGINE = InnoDB;


-- ------------------------------------------------
-- Table `RNAi_analysis_database`.`Instrument_used`
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Instrument_used` (
  `Instrument_used_ID` INT NOT NULL AUTO_INCREMENT,
  `Instrument_name` VARCHAR(45) NULL,
  PRIMARY KEY (`Instrument_used_ID`))
ENGINE = InnoDB;


-- --------------------------------------------
-- Table `RNAi_analysis_database`.`Tissue_type`
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Tissue_type` (
  `Tissue_type_ID` INT NOT NULL AUTO_INCREMENT,
  `Tissue_of_origin` VARCHAR(45) NULL,
  PRIMARY KEY (`Tissue_type_ID`))
ENGINE = InnoDB;


-- ----------------------------------------------------------
-- Table `RNAi_analysis_database`.`Transfection_reagent_used`
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Transfection_reagent_used` (
  `Transfection_reagent_used_ID` INT NOT NULL AUTO_INCREMENT,
  `Transfection_reagent` VARCHAR(45) NULL,
  PRIMARY KEY (`Transfection_reagent_used_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------------
-- Table `RNAi_analysis_database`.`Template_library_file_path`
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Template_library_file_path` (
  `Template_library_file_path_ID` INT NOT NULL AUTO_INCREMENT,
  `Template_library_file_location` VARCHAR(100) NULL,
  PRIMARY KEY (`Template_library_file_path_ID`))
ENGINE = InnoDB;


-- ----------------------------------------------------
-- Table `RNAi_analysis_database`.`Plateconf_file_path`
-- ----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Plateconf_file_path` (
  `Plateconf_file_path_ID` INT NOT NULL AUTO_INCREMENT,
  `Plateconf_file_location` VARCHAR(100) NULL,
  PRIMARY KEY (`Plateconf_file_path_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `RNAi_analysis_database`.`Platelist_file_path`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Platelist_file_path` (
  `Platelist_file_path_ID` INT NOT NULL AUTO_INCREMENT,
  `Platelist_file_location` VARCHAR(100) NULL,
  PRIMARY KEY (`Platelist_file_path_ID`))
ENGINE = InnoDB;


-- --------------------------------------------------
-- Table `RNAi_analysis_database`.`Template_library`
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Template_library` (
  `Template_library_ID` INT NOT NULL AUTO_INCREMENT,
  `Template_library_name` VARCHAR(100) NULL,
  PRIMARY KEY (`Template_library_ID`))
ENGINE = InnoDB;


-- -------------------------------------------------------
-- Table `RNAi_analysis_database`.`Template_library_file`
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Template_library_file` (
  `Template_library_file_ID` INT NOT NULL AUTO_INCREMENT,
  `Plate_templib` VARCHAR(10) NULL,
  `Well_templib` VARCHAR(10) NULL,
  `Gene_symbol_templib` VARCHAR(20) NULL,
  `Entrez_gene_id_templib` VARCHAR(20) NULL,
  `Sub_lib` VARCHAR(10) NULL,
  `Template_library_Template_library_ID` INT NULL,
  PRIMARY KEY (`Template_library_file_ID`),
  INDEX `fk_Template_library_file_Template_library1_idx` (`Template_library_Template_library_ID` ASC),
  CONSTRAINT `fk_Template_library_file_Template_library1`
    FOREIGN KEY (`Template_library_Template_library_ID`)
    REFERENCES `RNAi_analysis_database`.`Template_library` (`Template_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `RNAi_analysis_database`.`Rnai_screen_info`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Rnai_screen_info` (
  `Rnai_screen_info_ID` INT NOT NULL AUTO_INCREMENT,
  `Cell_line` VARCHAR(45) NULL,
  `Rnai_screen_name` VARCHAR(100) NULL,
  `Date_of_run` VARCHAR(45) NULL,
  `Operator` VARCHAR(45) NULL,
  `Is_isogenic` VARCHAR(45) NULL,
  `Gene_name_if_isogenic` VARCHAR(45) NULL,
  `Isogenic_mutant_description` VARCHAR(45) NULL,
  `Method_of_isogenic_knockdown` VARCHAR(45) NULL,
  `Rnai_template_library` VARCHAR(45) NULL,
  `Plate_list_file_name` VARCHAR(45) NULL,
  `Plate_conf_file_name` VARCHAR(45) NULL,
  `Rnai_screen_link_to_report` VARCHAR(500) NULL,
  `Rnai_screen_link_to_qc_plots` VARCHAR(500) NULL,
  `Zprime` VARCHAR(45) NULL,
  `Notes` VARCHAR(1000) NULL,
  `Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID` INT NULL,
  `Instrument_used_Instrument_used_ID` INT NULL,
  `Tissue_type_Tissue_type_ID` INT NULL,
  `Transfection_reagent_used_Transfection_reagent_used_ID` INT NULL,
  `Template_library_file_path_Template_library_file_path_ID` INT NULL,
  `Plateconf_file_path_Plateconf_file_path_ID` INT NULL,
  `Platelist_file_path_Platelist_file_path_ID` INT NULL,
  `Template_library_Template_library_ID` INT NULL,
  PRIMARY KEY (`Rnai_screen_info_ID`),
  INDEX `fk_Rnai_screen_info_Name_of_set_if_isogenic1_idx` (`Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID` ASC),
  INDEX `fk_Rnai_screen_info_Instrument_used1_idx` (`Instrument_used_Instrument_used_ID` ASC),
  INDEX `fk_Rnai_screen_info_Tissue_type1_idx` (`Tissue_type_Tissue_type_ID` ASC),
  INDEX `fk_Rnai_screen_info_Transfection_reagent_used1_idx` (`Transfection_reagent_used_Transfection_reagent_used_ID` ASC),
  INDEX `fk_Rnai_screen_info_Template_library_file_path1_idx` (`Template_library_file_path_Template_library_file_path_ID` ASC),
  INDEX `fk_Rnai_screen_info_Plateconf_file_path1_idx` (`Plateconf_file_path_Plateconf_file_path_ID` ASC),
  INDEX `fk_Rnai_screen_info_Platelist_file_path1_idx` (`Platelist_file_path_Platelist_file_path_ID` ASC),
  INDEX `fk_Rnai_screen_info_Template_library1_idx` (`Template_library_Template_library_ID` ASC),
  CONSTRAINT `fk_Rnai_screen_info_Name_of_set_if_isogenic1`
    FOREIGN KEY (`Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID`)
    REFERENCES `RNAi_analysis_database`.`Name_of_set_if_isogenic` (`Name_of_set_if_isogenic_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Instrument_used1`
    FOREIGN KEY (`Instrument_used_Instrument_used_ID`)
    REFERENCES `RNAi_analysis_database`.`Instrument_used` (`Instrument_used_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Tissue_type1`
    FOREIGN KEY (`Tissue_type_Tissue_type_ID`)
    REFERENCES `RNAi_analysis_database`.`Tissue_type` (`Tissue_type_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Transfection_reagent_used1`
    FOREIGN KEY (`Transfection_reagent_used_Transfection_reagent_used_ID`)
    REFERENCES `RNAi_analysis_database`.`Transfection_reagent_used` (`Transfection_reagent_used_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Template_library_file_path1`
    FOREIGN KEY (`Template_library_file_path_Template_library_file_path_ID`)
    REFERENCES `RNAi_analysis_database`.`Template_library_file_path` (`Template_library_file_path_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Plateconf_file_path1`
    FOREIGN KEY (`Plateconf_file_path_Plateconf_file_path_ID`)
    REFERENCES `RNAi_analysis_database`.`Plateconf_file_path` (`Plateconf_file_path_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Platelist_file_path1`
    FOREIGN KEY (`Platelist_file_path_Platelist_file_path_ID`)
    REFERENCES `RNAi_analysis_database`.`Platelist_file_path` (`Platelist_file_path_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Template_library1`
    FOREIGN KEY (`Template_library_Template_library_ID`)
    REFERENCES `RNAi_analysis_database`.`Template_library` (`Template_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `RNAi_analysis_database`.`Plate_excel_file_as_text`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Plate_excel_file_as_text` (
  `Plate_excel_file_as_text_ID` INT NOT NULL AUTO_INCREMENT,
  `Plate_number_xls_file` VARCHAR(3) NULL,
  `Well_number_xls_file` VARCHAR(11) NULL,
  `Raw_score_xls_file` INT(11) NULL,
  `Rnai_screen_info_Rnai_screen_info_ID` INT NULL,
  PRIMARY KEY (`Plate_excel_file_as_text_ID`),
  INDEX `fk_Plate_excel_file_as_text_Rnai_screen_info1_idx` (`Rnai_screen_info_Rnai_screen_info_ID` ASC),
  CONSTRAINT `fk_Plate_excel_file_as_text_Rnai_screen_info1`
    FOREIGN KEY (`Rnai_screen_info_Rnai_screen_info_ID`)
    REFERENCES `RNAi_analysis_database`.`Rnai_screen_info` (`Rnai_screen_info_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `RNAi_analysis_database`.`Zscores_result`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Zscores_result` (
  `Zscores_result_ID` INT NOT NULL AUTO_INCREMENT,
  `Compound` VARCHAR(45) NULL,
  `Plate_number_for_zscore` VARCHAR(3) NULL,
  `Well_number_for_zscore` VARCHAR(11) NULL,
  `Zscore` VARCHAR(45) NULL,
  `Rnai_screen_info_Rnai_screen_info_ID` INT NULL,
  `Template_library_Template_library_ID` INT NULL,
  PRIMARY KEY (`Zscores_result_ID`),
  INDEX `fk_Zscores_result_Rnai_screen_info1_idx` (`Rnai_screen_info_Rnai_screen_info_ID` ASC),
  INDEX `fk_Zscores_result_Template_library1_idx` (`Template_library_Template_library_ID` ASC),
  CONSTRAINT `fk_Zscores_result_Rnai_screen_info1`
    FOREIGN KEY (`Rnai_screen_info_Rnai_screen_info_ID`)
    REFERENCES `RNAi_analysis_database`.`Rnai_screen_info` (`Rnai_screen_info_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Zscores_result_Template_library1`
    FOREIGN KEY (`Template_library_Template_library_ID`)
    REFERENCES `RNAi_analysis_database`.`Template_library` (`Template_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `RNAi_analysis_database`.`Summary_of_result`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`Summary_of_result` (
  `Summary_of_result_ID` INT NOT NULL AUTO_INCREMENT,
  `Plate_number_for_summary` VARCHAR(3) NULL,
  `Position` VARCHAR(45) NULL,
  `Zscore_summary` VARCHAR(45) NULL,
  `Well_number_for_summary` VARCHAR(11) NULL,
  `Well_anno` VARCHAR(45) NULL,
  `Final_well_anno` VARCHAR(45) NULL,
  `Raw_r1_ch1` VARCHAR(45) NULL,
  `Raw_r2_ch1` VARCHAR(45) NULL,
  `Raw_r3_ch1` VARCHAR(45) NULL,
  `Median_ch1` VARCHAR(45) NULL,
  `Average_ch1` VARCHAR(45) NULL,
  `Raw_plate_median_r1_ch1` VARCHAR(45) NULL,
  `Raw_plate_median_r2_ch1` VARCHAR(45) NULL,
  `Raw_plate_median_r3_ch1` VARCHAR(45) NULL,
  `Normalized_r1_ch1` VARCHAR(45) NULL,
  `Normalized_r2_ch1` VARCHAR(45) NULL,
  `Normalized_r3_ch1` VARCHAR(45) NULL,
  `Gene_id_summary` VARCHAR(45) NULL,
  `Precursor_summary` VARCHAR(45) NULL,
  `Rnai_screen_info_Rnai_screen_info_ID` INT NULL,
  `Template_library_Template_library_ID` INT NULL,
  PRIMARY KEY (`Summary_of_result_ID`),
  INDEX `fk_Summary_of_result_Rnai_screen_info1_idx` (`Rnai_screen_info_Rnai_screen_info_ID` ASC),
  INDEX `fk_Summary_of_result_Template_library1_idx` (`Template_library_Template_library_ID` ASC),
  CONSTRAINT `fk_Summary_of_result_Rnai_screen_info1`
    FOREIGN KEY (`Rnai_screen_info_Rnai_screen_info_ID`)
    REFERENCES `RNAi_analysis_database`.`Rnai_screen_info` (`Rnai_screen_info_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Summary_of_result_Template_library1`
    FOREIGN KEY (`Template_library_Template_library_ID`)
    REFERENCES `RNAi_analysis_database`.`Template_library` (`Template_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `RNAi_analysis_database`.`User_info`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `RNAi_analysis_database`.`User_info` (
  `User_info_ID` INT NOT NULL AUTO_INCREMENT,
  `Username` VARCHAR(50) NULL,
  `Password` VARCHAR(100) NULL,
  PRIMARY KEY (`User_info_ID`))
ENGINE = InnoDB;



-- CREATE USER 'AditiGulati' IDENTIFIED BY 'aditigulati';

-- GRANT ALL ON `RNAi_analysis_database`.* TO 'AditiGulati';

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
