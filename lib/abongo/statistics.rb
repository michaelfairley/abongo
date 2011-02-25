module Abongo::Statistics

  HANDY_Z_SCORE_CHEATSHEET = [[0.10, 1.29], [0.05, 1.65], [0.01, 2.33], [0.001, 3.08]]
  
  PERCENTAGES = {0.10 => '90%', 0.05 => '95%', 0.01 => '99%', 0.001 => '99.9%'}
  
  DESCRIPTION_IN_WORDS = {0.10 => 'fairly confident', 0.05 => 'confident',
                         0.01 => 'very confident', 0.001 => 'extremely confident'}

  def self.zscore(alternatives)
    if alternatives.size != 2
      raise "Sorry, can't currently automatically calculate statistics for A/B tests with > 2 alternatives."
    end

    if (alternatives[0]['participants'] == 0) || (alternatives[1]['participants'] == 0)
      raise "Can't calculate the z score if either of the alternatives lacks participants."
    end

    cr1 = conversion_rate(alternatives[0])
    cr2 = conversion_rate(alternatives[1])

    n1 = alternatives[0]['participants']
    n2 = alternatives[1]['participants']

    numerator = cr1 - cr2
    frac1 = cr1 * (1 - cr1) / n1
    frac2 = cr2 * (1 - cr2) / n2

    numerator / ((frac1 + frac2) ** 0.5)
  end

  def self.p_value(alternatives)
    index = 0
    z = zscore(alternatives)
    z = z.abs
    found_p = nil
    while index < HANDY_Z_SCORE_CHEATSHEET.size do
      if (z > HANDY_Z_SCORE_CHEATSHEET[index][1])
        found_p = HANDY_Z_SCORE_CHEATSHEET[index][0]
      end
      index += 1
    end
    found_p
  end

  def self.is_statistically_significant?(p = 0.05)
    p_value <= p
  end
  
  def self.conversion_rate(exp)
    1.0 * exp['conversions'] / exp['participants']
  end

  def self.pretty_conversion_rate(exp)
    sprintf("%4.2f%%", conversion_rate(exp) * 100)
  end

  def self.describe_result_in_words(experiment, alternatives)
    begin
      z = zscore(alternatives)
    rescue
      return "Could not execute the significance test because one or more of the alternatives has not been seen yet."
    end
    p = p_value(alternatives)

    words = ""
    if (alternatives[0]['participants'] < 10) || (alternatives[1]['participants'] < 10)
      words += "Take these results with a grain of salt since your samples are so small: "
    end

    best_alternative = alternatives.max{|a, b| conversion_rate(a) <=> conversion_rate(b)}
    alts = alternatives - [best_alternative]
    worst_alternative = alts.first

    words += "The best alternative you have is: [#{best_alternative['content']}], which had "
    words += "#{best_alternative['conversions']} conversions from #{best_alternative['participants']} participants "
    words += "(#{pretty_conversion_rate(best_alternative)}).  The other alternative was [#{worst_alternative['content']}], "
    words += "which had #{worst_alternative['conversions']} conversions from #{worst_alternative['participants']} participants "
    words += "(#{pretty_conversion_rate(worst_alternative)}).  "

    if (p.nil?)
      words += "However, this difference is not statistically significant."
    else
      words += "This difference is #{PERCENTAGES[p]} likely to be statistically significant, which means you can be "
      words += "#{DESCRIPTION_IN_WORDS[p]} that it is the result of your alternatives actually mattering, rather than "
      words += "being due to random chance.  However, this statistical test can't measure how likely the currently "
      words += "observed magnitude of the difference is to be accurate or not.  It only says \"better\", not \"better "
      words += "by so much\"."
    end
    words
  end

end
