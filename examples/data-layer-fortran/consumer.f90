program consumer
    use, intrinsic :: iso_fortran_env, only: int32, real64
    implicit none

    integer, parameter :: count = 10
    integer(int32) :: values(count)
    real(real64) :: mean
    integer :: unit

    open(newunit=unit, file='fft-input.bin', access='stream', form='unformatted', &
         status='old', action='read')
    read(unit) values
    close(unit)

    mean = sum(real(values, real64)) / real(count, real64)
    print '(a, 10(1x, i0))', 'Consumer received:', values
    print '(a, f0.2)', 'Mean: ', mean
end program consumer
