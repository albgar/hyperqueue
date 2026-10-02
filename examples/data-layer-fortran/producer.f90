program producer
    use, intrinsic :: iso_fortran_env, only: int32, real64
    implicit none

    integer, parameter :: count = 10
    integer(int32) :: values(count)
    real(real64) :: random_values(count)
    integer :: unit

    call random_number(random_values)
    values = int(random_values * 100.0_real64, int32) + 1_int32

    ! Stream/unformatted gives a file containing exactly ten int32 values.
    open(newunit=unit, file='producer-result.bin', access='stream', form='unformatted', &
         status='replace', action='write')
    write(unit) values
    close(unit)

    print '(a, 10(1x, i0))', 'Producer generated:', values
end program producer
