program consumer
    use, intrinsic :: iso_fortran_env, only: int32, real64
    implicit none

    integer, parameter :: count = 10
    integer(int32) :: values(count)
    real(real64) :: factor, mean, scaled_values(count)
    integer :: unit

    open(newunit=unit, file='array-input.bin', access='stream', form='unformatted', &
         status='old', action='read')
    read(unit) values
    close(unit)

    open(newunit=unit, file='factor-input.bin', access='stream', form='unformatted', &
         status='old', action='read')
    read(unit) factor
    close(unit)

    mean = sum(real(values, real64)) / real(count, real64)
    scaled_values = real(values, real64) * factor

    ! These two files are the consumer's own outputs, for channels 5 and 6.
    open(newunit=unit, file='consumer-mean.bin', access='stream', form='unformatted', &
         status='replace', action='write')
    write(unit) mean
    close(unit)

    open(newunit=unit, file='consumer-scaled-array.bin', access='stream', form='unformatted', &
         status='replace', action='write')
    write(unit) scaled_values
    close(unit)

    print '(a, 10(1x, i0))', 'Consumer received array:', values
    print '(a, f0.6)', 'Consumer received factor: ', factor
    print '(a, f0.2)', 'Mean (output channel 5): ', mean
    print '(a, 10(1x, f0.2))', 'Scaled array (output channel 6):', scaled_values
end program consumer
