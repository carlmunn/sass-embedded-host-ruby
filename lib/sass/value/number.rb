# frozen_string_literal: true

module Sass
  class Value
    # Sass's number type.
    class Number < Sass::Value
      def initialize(value, numerator_units = [], denominator_units = []) # rubocop:disable Lint/MissingSuper
        numerator_units = [numerator_units] if numerator_units.is_a?(::String)
        denominator_units = [denominator_units] if denominator_units.is_a?(::String)

        unless denominator_units.empty? && numerator_units.empty?
          value = value.dup
          numerator_units = numerator_units.dup
          new_denominator_units = []

          denominator_units.each do |denominator_unit|
            index = numerator_units.find_index do |numerator_unit|
              factor = Unit.conversion_factor(denominator_unit, numerator_unit)
              if factor.nil?
                false
              else
                value *= factor
                true
              end
            end
            if index.nil?
              new_denominator_units.push(denominator_unit)
            else
              numerator_units.delete_at(index)
            end
          end

          denominator_units = new_denominator_units
        end

        @value = value.freeze
        @numerator_units = numerator_units.freeze
        @denominator_units = denominator_units.freeze
      end

      attr_reader :value, :numerator_units, :denominator_units

      def unitless?
        numerator_units.empty? && denominator_units.empty?
      end

      def assert_unitless(name = nil)
        raise error "Expected #{self} to have no units", name unless unitless?
      end

      def units?
        !unitless?
      end

      def unit?(unit)
        single_unit? && numerator_units.first == unit
      end

      def assert_unit(unit, name = nil)
        raise error "Expected #{self} to have no unit \"#{unit}\"", name unless unit?(unit)
      end

      def integer?
        FuzzyMath.integer?(value)
      end

      def assert_integer(_name = nil)
        raise error "#{self} is not an integer" unless integer?

        to_i
      end

      def to_i
        FuzzyMath.to_i(value)
      end

      def assert_between(min, max, name = nil)
        FuzzyMath.assert_between(value, min, max, name)
      end

      def compatible_with_unit?(unit)
        single_unit? && !Unit.conversion_factor(numerator_units.first, unit).nil?
      end

      def convert(new_numerator_units, new_denominator_units, name = nil)
        Number.new(convert_value(new_numerator_units, new_denominator_units, name), new_numerator_units,
                   new_denominator_units)
      end

      def convert_value(new_numerator_units, new_denominator_units, name = nil)
        coerce_or_convert_value(new_numerator_units, new_denominator_units,
                                coerce_unitless: false,
                                name: name)
      end

      def convert_to_match(other, name = nil, other_name = nil)
        Number.new(convert_value_to_match(other, name, other_name), other.numerator_units, other.denominator_units)
      end

      def convert_value_to_match(other, name = nil, other_name = nil)
        coerce_or_convert_value(other.numerator_units, other.denominator_units,
                                coerce_unitless: false,
                                name: name,
                                other: other,
                                other_name: other_name)
      end

      def coerce(new_numerator_units, new_denominator_units, name = nil)
        Number.new(coerce_value(new_numerator_units, new_denominator_units, name), new_numerator_units,
                   new_denominator_units)
      end

      def coerce_value(new_numerator_units, new_denominator_units, name = nil)
        coerce_or_convert_value(new_numerator_units, new_denominator_units,
                                coerce_unitless: true,
                                name: name)
      end

      def coerce_value_to_unit(unit, name = nil)
        coerce_value([unit], [], name)
      end

      def coerce_to_match(other, name = nil, other_name = nil)
        Number.new(coerce_value_to_match(other, name, other_name), other.numerator_units, other.denominator_units)
      end

      def coerce_value_to_match(other, name = nil, other_name = nil)
        coerce_or_convert_value(other.numerator_units, other.denominator_units,
                                coerce_unitless: true,
                                name: name,
                                other: other,
                                other_name: other_name)
      end

      def assert_number(_name = nil)
        self
      end

      def ==(other)
        return false unless other.is_a? Sass::Value::Number

        return false if numerator_units.length != other.numerator_units.length ||
                        denominator_units.length != other.denominator_units.length

        return FuzzyMath.equals(value, other.value) if unitless?

        if Unit.canonicalize_units(numerator_units) != Unit.canonicalize_units(other.numerator_units) &&
           Unit.canonicalize_units(denominator_units) != Unit.canonicalize_units(other.denominator_units)
          return false
        end

        FuzzyMath.equals(
          (value *
          Unit.canonical_multiplier(numerator_units) /
          Unit.canonical_multiplier(denominator_units)),
          (other.value *
          Unit.canonical_multiplier(other.numerator_units) /
          Unit.canonical_multiplier(other.denominator_units))
        )
      end

      def hash
        @hash ||= if unitless?
                    FuzzyMath.hash(value)
                  elsif single_unit?
                    FuzzyMath.hash(
                      value * Unit.canonical_multiplier_for_unit(numerator_units.first)
                    )
                  else
                    FuzzyMath.hash(
                      value * Unit.canonical_multiplier(numerator_units) / Unit.canonical_multiplier(denominator_units)
                    )
                  end
      end

      protected

      def single_unit?
        numerator_units.length == 1 && denominator_units.empty?
      end

      def coerce_or_convert_value(new_numerator_units, new_denominator_units,
                                  coerce_unitless:,
                                  name: nil,
                                  other: nil,
                                  other_name: nil)
        if other && (other.numerator_units != new_denominator_units && other.denominator_units != new_denominator_units)
          raise error "Expect #{other} to have units #{unit_string(new_numerator_units, new_denominator_units)}"
        end

        return value if numerator_units == new_numerator_units && denominator_units == new_denominator_units

        return value if numerator_units == new_numerator_units && denominator_units == new_denominator_units

        other_unitless = new_numerator_units.empty? && new_denominator_units.empty?

        return value if coerce_unitless && (unitless? || other_unitless)

        compatibility_error = lambda {
          unless other.nil?
            message = +"#{self} and"
            message << " $#{other_name}:" unless other_name.nil?
            message << " #{other} have incompatible units"
            message << " (one has units and the other doesn't)" if unitless? || other_unitless
            return error message, name
          end

          return error "Expected #{self} to have no units", name unless other_unitless

          if new_numerator_units.length == 1 && new_denominator_units.empty?
            type = Unit::TYPES_BY_UNIT[new_numerator_units.first]
            return error "Expected #{self} to have a #{type} unit (#{Unit::UNITS_BY_TYPE[type].join(', ')})", name
          end

          unit_length = new_numerator_units.length + new_denominator_units.length
          units = unit_string(new_numerator_units, new_denominator_units)
          error "Expected #{self} to have unit#{unit_length > 1 ? 's' : ''} #{units}", name
        }

        result = value

        old_numerator_units = numerator_units.dup
        new_numerator_units.each do |new_numerator_unit|
          index = old_numerator_units.find_index do |old_numerator_unit|
            factor = Unit.conversion_factor(new_numerator_unit, old_numerator_unit)
            if factor.nil?
              false
            else
              result *= factor
              true
            end
          end
          raise compatibility_error.call if index.nil?

          old_numerator_units.delete_at(index)
        end

        old_denominator_units = denominator_units.dup
        new_denominator_units.each do |new_denominator_unit|
          index = old_denominator_units.find_index do |old_denominator_unit|
            factor = Unit.conversion_factor(new_denominator_unit, old_denominator_unit)
            if factor.nil?
              false
            else
              result /= factor
              true
            end
          end
          raise compatibility_error.call if index.nil?

          old_denominator_units.delete_at(index)
        end

        raise compatibility_error.call unless old_numerator_units.empty? && old_denominator_units.empty?

        result
      end

      def unit_string(numerator_units, denominator_units)
        if numerator_units.empty?
          return 'no units' if denominator_units.empty?

          return denominator_units.length == 1 ? "#{denominator_units.first}^-1" : "(#{denominator_units.join('*')})^-1"
        end

        return numerator_units.join('*') if denominator_units.empty?

        "#{numerator_units.join('*')}/#{denominator_units.join('*')}"
      end
    end
  end
end